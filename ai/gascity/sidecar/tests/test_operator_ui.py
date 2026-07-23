from __future__ import annotations

import asyncio
import re
import tomllib
from pathlib import Path
from typing import Any

from fastapi.testclient import TestClient

from gascity_sidecar.api import create_app
from gascity_sidecar.config import Settings
from gascity_sidecar.events import EventProcessor
from gascity_sidecar.state import StateStore


RESULT_FIELDS = {
    "previous_state",
    "new_state",
    "gc_operation_performed",
    "applies_to",
    "warnings",
}


class FakeGCClient:
    """A deterministic client that keeps the sidecar test independent of a city."""

    city_name = "demo-city"

    def __init__(self, city_path: Path, *, active: bool = True) -> None:
        self.city_path = city_path
        self.active = active
        self.reload_calls = 0
        self.stop_calls = 0
        self.kill_calls = 0
        self.snapshot_calls = 0

        self._sessions = (
            [
                {
                    "id": "session-7",
                    "provider": "codex",
                    "state": "running",
                    "worker": "worker-a",
                }
            ]
            if active
            else []
        )
        self._workflows = (
            [
                {
                    "id": "workflow-7",
                    "name": "release",
                    "status": "running",
                }
            ]
            if active
            else []
        )

    async def status(self) -> dict[str, Any]:
        return {
            "ok": True,
            "running": True,
            "city": self.city_name,
            "sessions": list(self._sessions),
            "workflows": list(self._workflows),
        }

    async def snapshot(self) -> dict[str, Any]:
        self.snapshot_calls += 1
        status = await self.status()
        return {
            "status": status,
            "sessions": list(self._sessions),
            "workflows": list(self._workflows),
        }

    async def reload(self) -> None:
        self.reload_calls += 1

    async def stop(self) -> None:
        self.stop_calls += 1

    async def kill(self) -> None:
        self.kill_calls += 1

    async def stream_events(self, after: int = 0):
        """Remain cancellable so TestClient shutdown never waits on a live stream."""
        del after
        while True:
            await asyncio.sleep(3600)
            if False:  # pragma: no cover - keeps this function an async generator
                yield {}


def _app(
    tmp_path: Path,
    *,
    bind_host: str = "127.0.0.1",
    allow_public: bool = False,
    active: bool = True,
):
    city_path = tmp_path / "demo-city"
    city_path.mkdir()
    (city_path / "city.toml").write_text('include = ["city.sidecar.toml"]\n')
    settings = Settings(
        city_path=city_path,
        state_db_path=tmp_path / "state.sqlite3",
        bind_host=bind_host,
        allow_non_loopback_bind=allow_public,
    )
    store = StateStore(settings.state_db_path)
    fake = FakeGCClient(city_path, active=active)
    return create_app(settings, state_store=store, gc_client=fake), store, fake


def _seed_recent_event(store: StateStore) -> None:
    EventProcessor(store).process(
        {
            "seq": 7,
            "type": "workflow.started",
            "ts": "2026-07-23T12:00:00Z",
            "id": "event-7",
            "subject": "workflow-7",
            "message": "release started",
        }
    )


def _assert_result(response) -> dict[str, Any]:
    assert response.status_code == 200, response.text
    payload = response.json()
    assert set(payload) == RESULT_FIELDS
    return payload


def _assert_form(html: str, action: str, method: str = "post") -> None:
    forms = re.findall(r"<form\b[^>]*>", html, flags=re.IGNORECASE)
    action_pattern = re.compile(
        rf"\baction=[\"']{re.escape(action)}[\"']", re.IGNORECASE
    )
    method_pattern = re.compile(
        rf"\bmethod=[\"']{re.escape(method)}[\"']", re.IGNORECASE
    )
    matching = [form for form in forms if action_pattern.search(form)]
    assert matching, f"no form for {action}: {html}"
    assert any(method_pattern.search(form) for form in matching)


def test_operator_page_renders_status_workflows_sessions_events_and_controls(
    tmp_path: Path,
) -> None:
    app, store, fake = _app(tmp_path)
    _seed_recent_event(store)

    # Entering and leaving this context also verifies that a fake event stream is
    # cancelled cleanly during shutdown rather than hanging the TestClient.
    with TestClient(app) as client:
        status = client.get("/status")
        assert status.status_code == 200
        status_payload = status.json()
        assert status_payload["sessions"] == fake._sessions
        assert status_payload["workflows"] == fake._workflows

        response = client.get("/")
        assert response.status_code == 200
        body = response.text
        lowered = body.lower()
        assert 'http-equiv="refresh"' in lowered
        assert re.search(r"\bcontent=[\"']5(?:[\"']|;)", lowered)
        for value in (
            "workflow-7",
            "release",
            "session-7",
            "worker-a",
            "event-7",
            "workflow_started",
            "2026-07-23T12:00:00Z",
            "release started",
        ):
            assert value in body
        for heading in ("status", "workflow", "session", "recent event"):
            assert heading in lowered

        # Native forms expose every JSON control, while stop remains a separate
        # typed-confirmation page.
        _assert_form(body, "/ui/control/pause")
        _assert_form(body, "/ui/control/resume")
        _assert_form(body, "/ui/control/drain")
        _assert_form(body, "/ui/control/concurrency")
        _assert_form(body, "/ui/control/max-repair-attempts")
        _assert_form(body, "/ui/control/codex-budget-mode")
        assert "new dispatches only" in lowered
        assert "/stop" in body

        stop_page = client.get("/stop")
        assert stop_page.status_code == 200
        stop_body = stop_page.text.lower()
        assert not re.search(r"<meta\b[^>]*http-equiv=[\"']refresh", stop_body)
        assert "demo-city" in stop_body
        assert re.search(r"\bname=[\"']confirmation[\"']", stop_body)


def test_json_controls_have_exact_result_shape_and_concurrency_reload(
    tmp_path: Path,
) -> None:
    app, _store, fake = _app(tmp_path, active=False)

    with TestClient(app) as client:
        for route in ("/control/pause", "/control/resume", "/control/drain"):
            payload = _assert_result(client.post(route))
            assert payload["gc_operation_performed"] is None
        payload = _assert_result(client.put("/control/concurrency", json={"value": 4}))
        assert payload["gc_operation_performed"] == "reload"

        sidecar_config = fake.city_path / "city.sidecar.toml"
        assert sidecar_config.exists()
        assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
            "workspace": {"max_active_sessions": 4}
        }

        payload = _assert_result(
            client.put("/control/codex-budget-mode", json={"mode": "conserve"})
        )
        assert payload["gc_operation_performed"] == "reload"
        conserve_warning = " ".join(payload["warnings"]).lower()
        assert "workspace cap" in conserve_warning
        assert "v1.3.5" in conserve_warning
        assert "per-provider" in conserve_warning
        assert "non-codex" in conserve_warning
        assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
            "workspace": {"max_active_sessions": 1}
        }

        payload = _assert_result(
            client.put("/control/codex-budget-mode", json={"mode": "normal"})
        )
        assert payload["gc_operation_performed"] == "reload"
        assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
            "workspace": {"max_active_sessions": 4}
        }
        assert not (fake.city_path / "city.local.toml").exists()
        assert not (fake.city_path / ".gc").exists()
        assert fake.reload_calls >= 3
        assert fake.stop_calls == 0
        assert fake.kill_calls == 0

        # Control is not exposed as an unguarded JSON stop route.
        assert client.get("/control/stop").status_code == 404


def test_form_pause_renders_all_control_result_fields_and_loopback_mutates(
    tmp_path: Path,
) -> None:
    app, _store, fake = _app(tmp_path, active=False)

    with TestClient(app) as client:
        response = client.post("/ui/control/pause")
        assert response.status_code == 200, response.text
        for field in RESULT_FIELDS:
            assert field in response.text

        # A loopback bind permits every native control and JSON mutation.
        assert client.post("/ui/control/resume").status_code == 200
        assert client.post("/ui/control/drain").status_code == 200
        assert (
            client.post("/ui/control/concurrency", data={"value": "4"}).status_code
            == 200
        )
        assert (
            client.post(
                "/ui/control/max-repair-attempts", data={"value": "2"}
            ).status_code
            == 200
        )
        assert (
            client.post(
                "/ui/control/codex-budget-mode", data={"mode": "conserve"}
            ).status_code
            == 200
        )
        assert client.post("/control/pause").status_code == 200
        assert fake.stop_calls == 0


def test_stop_requires_exact_typed_city_confirmation_and_calls_only_emergency_stop(
    tmp_path: Path,
) -> None:
    app, _store, fake = _app(tmp_path)

    with TestClient(app) as client:
        wrong = client.post("/stop", data={"confirmation": "wrong-city"})
        assert wrong.status_code in {400, 422}
        assert fake.stop_calls == 0
        assert fake.kill_calls == 0

        right = client.post("/stop", data={"confirmation": fake.city_name})
        assert right.status_code == 200, right.text
        for field in RESULT_FIELDS:
            assert f"<code>{field}</code>" in right.text
        assert "<code>gc_operation_performed</code>" in right.text
        assert "&quot;stop&quot;" in right.text
        assert fake.stop_calls == 1
        assert fake.kill_calls == 0


def test_non_loopback_bind_keeps_reads_but_forbids_every_mutation(
    tmp_path: Path,
) -> None:
    app, _store, fake = _app(
        tmp_path, bind_host="0.0.0.0", allow_public=True, active=False
    )

    with TestClient(app) as client:
        for route in ("/", "/status", "/events", "/health", "/stop"):
            assert client.get(route).status_code == 200

        json_mutations = (
            ("/control/pause", "post", None),
            ("/control/resume", "post", None),
            ("/control/drain", "post", None),
            ("/control/concurrency", "put", {"value": 4}),
            ("/control/max-repair-attempts", "put", {"value": 2}),
            ("/control/codex-budget-mode", "put", {"mode": "normal"}),
        )
        for route, method, payload in json_mutations:
            response = (
                getattr(client, method)(route, json=payload)
                if payload
                else getattr(client, method)(route)
            )
            assert response.status_code == 403, (route, response.text)

        form_mutations = (
            ("/ui/control/pause", {}),
            ("/ui/control/resume", {}),
            ("/ui/control/drain", {}),
            ("/ui/control/concurrency", {"concurrency": "4"}),
            ("/ui/control/max-repair-attempts", {"max_repair_attempts": "2"}),
            ("/ui/control/codex-budget-mode", {"mode": "normal"}),
            ("/stop", {"confirmation": fake.city_name}),
        )
        for route, form in form_mutations:
            response = client.post(route, data=form)
            assert response.status_code == 403, (route, response.text)
        assert fake.stop_calls == 0
        assert fake.kill_calls == 0
