"""FastAPI application for sidecar health, status, and operator controls."""

from __future__ import annotations

import html
import ipaddress
import json
from dataclasses import asdict, is_dataclass
from typing import Any, Awaitable, Callable
from urllib.parse import parse_qs

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse

from .config import Settings, validate_bind
from .control import ControlPlane, ControlResult
from .events import EventProcessor
from .gascity import GasCityClient, GasCityError
from .notifications import PushoverNotifier
from .state import StateStore


_RESULT_FIELDS = (
    "previous_state",
    "new_state",
    "gc_operation_performed",
    "applies_to",
    "warnings",
)


async def _client_snapshot(client: Any) -> dict[str, Any]:
    if hasattr(client, "snapshot"):
        result = await client.snapshot()
        if not isinstance(result, dict):
            raise TypeError("Gas City snapshot must be an object")
        return result
    status = await client.status()
    if not isinstance(status, dict):
        raise TypeError("Gas City status must be an object")
    sessions = status.get("sessions", status.get("running_sessions", []))
    workflows = status.get("workflows", status.get("active_workflows", []))
    return {"status": status, "sessions": sessions, "workflows": workflows}


def _gc_is_healthy(status: dict[str, Any]) -> bool:
    """Treat a reachable but stopped controller as degraded."""
    if status.get("ok") is False or status.get("running") is False:
        return False
    controller = status.get("controller")
    if isinstance(controller, dict) and controller.get("running") is False:
        return False
    health = status.get("health")
    if isinstance(health, dict) and health.get("usable") is False:
        return False
    return True


def _is_loopback_bind(host: str) -> bool:
    normalized = host.strip().lower()
    if normalized in {"localhost", "ip6-localhost"}:
        return True
    try:
        return ipaddress.ip_address(normalized).is_loopback
    except ValueError:
        return False


def _result_payload(result: ControlResult | Any) -> dict[str, Any]:
    if hasattr(result, "model_dump"):
        raw = result.model_dump(mode="json")
    elif is_dataclass(result):
        raw = asdict(result)
    elif isinstance(result, dict):
        raw = result
    else:
        raw = {name: getattr(result, name, None) for name in _RESULT_FIELDS}
    return {name: raw.get(name) for name in _RESULT_FIELDS}


def _json_value(payload: Any, names: tuple[str, ...]) -> Any:
    if isinstance(payload, dict):
        for name in names:
            if name in payload:
                return payload[name]
        raise ValueError(f"request body must include one of: {', '.join(names)}")
    if payload is None:
        raise ValueError("request body must contain a value")
    return payload


async def _request_json_value(request: Request, names: tuple[str, ...]) -> Any:
    try:
        payload = await request.json()
    except Exception as exc:
        raise ValueError("request body must be valid JSON") from exc
    return _json_value(payload, names)


async def _request_form(request: Request) -> dict[str, str]:
    raw = await request.body()
    try:
        decoded = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("form body must be UTF-8") from exc
    parsed = parse_qs(decoded, keep_blank_values=True)
    return {name: values[-1] if values else "" for name, values in parsed.items()}


def _display(value: Any) -> str:
    try:
        encoded = json.dumps(value, indent=2, sort_keys=True, default=str)
    except (TypeError, ValueError):
        encoded = str(value)
    return html.escape(encoded)


def _text(value: Any) -> str:
    return html.escape(str(value))


def _result_markup(result: Any) -> str:
    payload = _result_payload(result)
    rows = "".join(
        "<dt><code>"
        + _text(name)
        + "</code></dt><dd><pre>"
        + _display(payload[name])
        + "</pre></dd>"
        for name in _RESULT_FIELDS
    )
    return (
        '<section><h2>Control result</h2><dl class="control-result">'
        + rows
        + "</dl></section>"
    )


def _operator_page(
    *,
    city_name: str,
    payload: dict[str, Any],
    events: list[dict[str, Any]],
    result: Any | None = None,
    message: str | None = None,
) -> str:
    workflows = payload.get("workflows", [])
    sessions = payload.get("sessions", [])
    desired = payload.get("desired_state", payload.get("desired", {}))
    gc = payload.get("gc", {})
    message_markup = (
        '<p class="message">' + _text(message) + "</p>" if message is not None else ""
    )
    result_markup = _result_markup(result) if result is not None else ""
    return (
        '<!doctype html><html><head><meta charset="utf-8">'
        '<meta http-equiv="refresh" content="5">'
        "<title>Gas City Sidecar - " + _text(city_name) + "</title></head><body>"
        "<h1>Gas City Sidecar</h1><p>City: <strong>"
        + _text(city_name)
        + "</strong></p>"
        + message_markup
        + "<section><h2>Status</h2><pre>"
        + _display({"desired": desired, "gc": gc})
        + "</pre></section>"
        + "<section><h2>Active workflows</h2><pre>"
        + _display(workflows)
        + "</pre></section>"
        + "<section><h2>Active sessions</h2><pre>"
        + _display(sessions)
        + "</pre></section>"
        + "<section><h2>Recent events</h2><pre>"
        + _display(events)
        + "</pre></section>"
        "<section><h2>Controls</h2>"
        '<form method="post" action="/ui/control/pause"><button type="submit">Pause</button></form>'
        '<form method="post" action="/ui/control/resume"><button type="submit">Resume</button></form>'
        '<form method="post" action="/ui/control/drain"><button type="submit">Drain</button></form>'
        '<form method="post" action="/ui/control/concurrency">'
        '<label for="concurrency">Concurrency</label>'
        '<input id="concurrency" name="value" type="number" min="1" max="64" required>'
        '<button type="submit">Set concurrency</button></form>'
        '<form method="post" action="/ui/control/max-repair-attempts">'
        '<label for="max-repair-attempts">Max repair attempts (new dispatches only)</label>'
        '<input id="max-repair-attempts" name="value" type="number" min="0" max="100" required>'
        '<button type="submit">Set repair limit</button></form>'
        '<form method="post" action="/ui/control/codex-budget-mode">'
        '<label for="codex-budget-mode">Codex budget mode</label>'
        '<select id="codex-budget-mode" name="mode">'
        '<option value="normal">normal</option><option value="conserve">conserve</option>'
        '<option value="critical">critical</option><option value="paused">paused</option>'
        '</select><button type="submit">Set budget mode</button></form>'
        '</section><p><a href="/stop">Emergency stop</a></p>'
        + result_markup
        + "</body></html>"
    )


def _stop_page(
    *,
    city_name: str,
    error: str | None = None,
    result: Any | None = None,
) -> str:
    error_markup = '<p class="error">' + _text(error) + "</p>" if error else ""
    result_markup = _result_markup(result) if result is not None else ""
    return (
        '<!doctype html><html><head><meta charset="utf-8">'
        "<title>Emergency stop - "
        + _text(city_name)
        + "</title></head><body><h1>Emergency stop</h1>"
        "<p>City: <strong>"
        + _text(city_name)
        + "</strong></p>"
        + error_markup
        + "<p>Type the city name exactly to confirm stopping it.</p>"
        '<form method="post" action="/stop"><label for="confirmation">Confirmation</label>'
        '<input id="confirmation" name="confirmation" type="text" required>'
        '<button type="submit">Stop city</button></form>'
        '<p><a href="/">Back to status</a></p>' + result_markup + "</body></html>"
    )


def create_app(
    settings: Settings | None = None,
    *,
    state_store: StateStore | None = None,
    gc_client: Any | None = None,
) -> FastAPI:
    settings = settings or Settings()
    validate_bind(
        settings.bind_host, allow_non_loopback=settings.allow_non_loopback_bind
    )
    store = state_store or StateStore(settings.state_db_path)
    client = gc_client or GasCityClient(settings)
    control = ControlPlane(store, client, settings)

    app = FastAPI(title="Gas City Sidecar", version="0.1.0")
    app.state.settings = settings
    processor = EventProcessor(store, PushoverNotifier.from_environment())
    app.state.event_processor = processor
    app.state.event_task = None

    @app.on_event("startup")
    async def start_event_consumer() -> None:
        import asyncio

        if hasattr(client, "stream_events"):
            app.state.event_task = asyncio.create_task(processor.run(client))

    @app.on_event("shutdown")
    async def stop_event_consumer() -> None:
        import asyncio

        task = app.state.event_task
        if task is not None:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

    app.state.state_store = store
    app.state.gc_client = client
    app.state.control_plane = control
    mutations_allowed = _is_loopback_bind(settings.bind_host)

    async def load_status() -> dict[str, Any]:
        desired = store.load_desired_state()
        checkpoint = store.load_event_checkpoint()
        if checkpoint != desired.last_processed_event_sequence:
            desired = desired.model_copy(
                update={"last_processed_event_sequence": checkpoint}
            )
        try:
            snapshot = await _client_snapshot(client)
            gc_status = snapshot.get("status", {})
            sessions = snapshot.get("sessions", [])
            workflows = snapshot.get("workflows", [])
            if not isinstance(gc_status, dict):
                raise TypeError("Gas City status must be an object")
            if not isinstance(sessions, list) or not isinstance(workflows, list):
                raise TypeError("Gas City sessions/workflows must be arrays")
            gc_payload = {
                "status": "ok" if _gc_is_healthy(gc_status) else "degraded",
                "data": gc_status,
            }
        except GasCityError as exc:
            sessions, workflows = [], []
            gc_payload = {"status": "degraded", "error": str(exc)}
        except Exception as exc:
            sessions, workflows = [], []
            gc_payload = {"status": "degraded", "error": str(exc)}
        return {
            "desired_state": desired.model_dump(mode="json"),
            "desired": desired.model_dump(mode="json"),
            "gc": gc_payload,
            "sessions": sessions,
            "workflows": workflows,
        }

    async def recent_events() -> list[dict[str, Any]]:
        try:
            return store.load_recent_events(100)
        except Exception:
            return []

    async def invoke_json(operation: Callable[[], Awaitable[Any]], request: Request):
        if not mutations_allowed:
            return JSONResponse(
                status_code=403,
                content={"detail": "control mutations require a loopback bind"},
            )
        try:
            result = await operation()
        except ValueError as exc:
            return JSONResponse(status_code=422, content={"detail": str(exc)})
        return JSONResponse(content=_result_payload(result))

    async def invoke_form(
        operation: Callable[[dict[str, str]], Awaitable[Any]],
        request: Request,
    ) -> HTMLResponse:
        if not mutations_allowed:
            return HTMLResponse(
                "<!doctype html><html><body><h1>Forbidden</h1>"
                "<p>control mutations require a loopback bind</p></body></html>",
                status_code=403,
            )
        try:
            result = await operation(await _request_form(request))
        except ValueError as exc:
            return HTMLResponse(
                "<!doctype html><html><body><h1>Bad request</h1><p>"
                + _text(exc)
                + '</p><p><a href="/">Back to status</a></p></body></html>',
                status_code=400,
            )
        payload = await load_status()
        return HTMLResponse(
            _operator_page(
                city_name=_city_name(client, settings),
                payload=payload,
                events=await recent_events(),
                result=result,
            )
        )

    @app.get("/health")
    async def health() -> dict[str, str]:
        try:
            gc_status = await client.status()
            if not isinstance(gc_status, dict):
                raise TypeError("Gas City status must be an object")
        except GasCityError:
            return {"status": "degraded", "gc": "unavailable"}
        except Exception:
            return {"status": "degraded", "gc": "error"}
        if not _gc_is_healthy(gc_status):
            return {"status": "degraded", "gc": "degraded"}
        return {"status": "ok", "gc": "ok"}

    @app.get("/status")
    async def status() -> dict[str, Any]:
        return await load_status()

    @app.get("/events")
    async def events(limit: int = 100) -> list[dict[str, Any]]:
        return store.load_recent_events(limit)

    @app.get("/workflows")
    async def workflows() -> list[Any]:
        try:
            return list(await client.workflows())
        except Exception:
            return []

    @app.get("/workers")
    async def workers() -> list[Any]:
        try:
            if hasattr(client, "workers"):
                return list(await client.workers())
            if hasattr(client, "sessions"):
                return list(await client.sessions())
        except Exception:
            pass
        return []

    @app.post("/control/pause")
    async def control_pause(request: Request):
        return await invoke_json(control.pause, request)

    @app.post("/control/resume")
    async def control_resume(request: Request):
        return await invoke_json(control.resume, request)

    @app.post("/control/drain")
    async def control_drain(request: Request):
        return await invoke_json(control.drain, request)

    @app.put("/control/concurrency")
    async def control_concurrency(request: Request):
        async def operation() -> Any:
            value = await _request_json_value(request, ("value", "concurrency"))
            return await control.set_concurrency(value)

        return await invoke_json(operation, request)

    @app.put("/control/max-repair-attempts")
    async def control_max_repair_attempts(request: Request):
        async def operation() -> Any:
            value = await _request_json_value(
                request, ("value", "max_repair_attempts", "max-repair-attempts")
            )
            return await control.set_max_repair_attempts(value)

        return await invoke_json(operation, request)

    @app.put("/control/codex-budget-mode")
    async def control_codex_budget_mode(request: Request):
        async def operation() -> Any:
            value = await _request_json_value(
                request, ("value", "codex_budget_mode", "codex-budget-mode", "mode")
            )
            return await control.set_codex_budget_mode(value)

        return await invoke_json(operation, request)

    @app.post("/ui/control/pause")
    async def ui_control_pause(request: Request):
        return await invoke_form(lambda _: control.pause(), request)

    @app.post("/ui/control/resume")
    async def ui_control_resume(request: Request):
        return await invoke_form(lambda _: control.resume(), request)

    @app.post("/ui/control/drain")
    async def ui_control_drain(request: Request):
        return await invoke_form(lambda _: control.drain(), request)

    @app.post("/ui/control/concurrency")
    async def ui_control_concurrency(request: Request):
        async def operation(form: dict[str, str]) -> Any:
            raw_value = form.get("value", form.get("concurrency", ""))
            try:
                value = int(raw_value)
            except (TypeError, ValueError) as exc:
                raise ValueError("concurrency must be an integer") from exc
            return await control.set_concurrency(value)

        return await invoke_form(operation, request)

    @app.post("/ui/control/max-repair-attempts")
    async def ui_control_max_repair_attempts(request: Request):
        async def operation(form: dict[str, str]) -> Any:
            raw_value = form.get("value", form.get("max_repair_attempts", ""))
            try:
                value = int(raw_value)
            except (TypeError, ValueError) as exc:
                raise ValueError("max repair attempts must be an integer") from exc
            return await control.set_max_repair_attempts(value)

        return await invoke_form(operation, request)

    @app.post("/ui/control/codex-budget-mode")
    async def ui_control_codex_budget_mode(request: Request):
        async def operation(form: dict[str, str]) -> Any:
            value = form.get(
                "mode", form.get("codex_budget_mode", form.get("value", ""))
            )
            return await control.set_codex_budget_mode(value)

        return await invoke_form(operation, request)

    @app.get("/stop", response_class=HTMLResponse)
    async def stop_page() -> str:
        return _stop_page(city_name=_city_name(client, settings))

    @app.post("/stop", response_class=HTMLResponse)
    async def emergency_stop(request: Request) -> HTMLResponse:
        city_name = _city_name(client, settings)
        if not mutations_allowed:
            return HTMLResponse(
                "<!doctype html><html><body><h1>Forbidden</h1>"
                "<p>control mutations require a loopback bind</p></body></html>",
                status_code=403,
            )
        try:
            form = await _request_form(request)
            confirmation = form.get("confirmation", form.get("confirm", ""))
        except ValueError as exc:
            return HTMLResponse(
                _stop_page(city_name=city_name, error=str(exc)), status_code=400
            )
        if confirmation != city_name:
            return HTMLResponse(
                _stop_page(
                    city_name=city_name,
                    error="Confirmation did not match the city name; emergency stop was not invoked.",
                ),
                status_code=400,
            )
        try:
            result = await control.emergency_stop(confirmation)
        except ValueError as exc:
            return HTMLResponse(
                _stop_page(city_name=city_name, error=str(exc)), status_code=400
            )
        return HTMLResponse(_stop_page(city_name=city_name, result=result))

    @app.get("/", response_class=HTMLResponse)
    async def status_page() -> str:
        return _operator_page(
            city_name=_city_name(client, settings),
            payload=await load_status(),
            events=await recent_events(),
        )

    return app


def _city_name(client: Any, settings: Settings) -> str:
    try:
        name = getattr(client, "city_name")
        if name:
            return str(name)
    except Exception:
        pass
    try:
        return settings.city_path.resolve().name
    except Exception:
        return str(settings.city_path)
