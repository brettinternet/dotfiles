"""FastAPI application for sidecar health and read-only status."""

from __future__ import annotations

import html
import json
from typing import Any

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

from .config import Settings, validate_bind
from .gascity import GasCityClient, GasCityError
from .models import DesiredState
from .state import StateStore


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




def create_app(
    settings: Settings | None = None,
    *,
    state_store: StateStore | None = None,
    gc_client: Any | None = None,
) -> FastAPI:
    settings = settings or Settings()
    validate_bind(settings.bind_host, allow_non_loopback=settings.allow_non_loopback_bind)
    store = state_store or StateStore(settings.state_db_path)
    client = gc_client or GasCityClient(settings)

    app = FastAPI(title="Gas City Sidecar", version="0.1.0")
    app.state.settings = settings
    app.state.state_store = store
    app.state.gc_client = client

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
            # Keep the short key convenient for local operators while the explicit
            # key is the stable API field.
            "desired": desired.model_dump(mode="json"),
            "gc": gc_payload,
            "sessions": sessions,
            "workflows": workflows,
        }

    @app.get("/", response_class=HTMLResponse)
    async def status_page() -> str:
        payload = await status()
        rendered = html.escape(json.dumps(payload, indent=2, sort_keys=True))
        return (
            "<!doctype html><html><head><title>Gas City Sidecar</title></head>"
            "<body><h1>Gas City Sidecar</h1><pre>" + rendered + "</pre></body></html>"
        )

    return app
