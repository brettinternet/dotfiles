from __future__ import annotations

import asyncio
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from gascity_sidecar.api import create_app
from gascity_sidecar.config import Settings, validate_bind
from gascity_sidecar.gascity import (
    GasCityClient,
    GasCityCommandError,
    GasCitySchemaError,
    GasCityTimeout,
    _ApiUnavailable,
)
from gascity_sidecar.models import CodexBudgetMode, DesiredState
from gascity_sidecar.state import StateStore


def test_desired_state_survives_restart(tmp_path: Path) -> None:
    database = tmp_path / "state.sqlite3"
    first = StateStore(database)
    first.save_desired_state(
        DesiredState(
            paused=True,
            desired_concurrency=4,
            default_max_repair_attempts=7,
            codex_budget_mode=CodexBudgetMode.CONSERVE,
            active_backlog_sources=["backlog.md"],
            last_processed_event_sequence=12,
        )
    )
    first.save_event_checkpoint(12)

    second = StateStore(database)
    assert second.load_desired_state() == first.load_desired_state()
    assert second.load_event_checkpoint() == 12
    assert second.claim_notification("workflow:done")
    assert not second.claim_notification("workflow:done")


def test_non_loopback_bind_refused_by_default() -> None:
    with pytest.raises(ValueError, match="loopback"):
        validate_bind("0.0.0.0")
    validate_bind("127.0.0.1")
    validate_bind("0.0.0.0", allow_non_loopback=True)


def test_status_degrades_when_fake_gc_client_is_unavailable(tmp_path: Path) -> None:
    class FakeClient:
        async def status(self):
            raise GasCityTimeout("timed out")

    settings = Settings(state_db_path=tmp_path / "state.sqlite3")
    with TestClient(create_app(settings, gc_client=FakeClient())) as client:
        assert client.get("/health").json() == {"status": "degraded", "gc": "unavailable"}
        body = client.get("/status").json()
        assert body["gc"]["status"] == "degraded"
        assert client.get("/").status_code == 200


def test_cli_timeout(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    class Process:
        returncode = 0

        async def communicate(self):
            await asyncio.sleep(1)
            return b"", b""

        def kill(self):
            pass

    async def spawn(*args, **kwargs):
        return Process()

    monkeypatch.setattr(asyncio, "create_subprocess_exec", spawn)
    client = GasCityClient(city_path=tmp_path, timeout=0.01)
    with pytest.raises(GasCityTimeout):
        asyncio.run(client._run_cli("status", "status", "--json"))


def test_cli_nonzero_exit(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    class Process:
        returncode = 23

        async def communicate(self):
            return b"", b"failed"

    async def spawn(*args, **kwargs):
        return Process()

    monkeypatch.setattr(asyncio, "create_subprocess_exec", spawn)
    client = GasCityClient(city_path=tmp_path)
    with pytest.raises(GasCityCommandError) as raised:
        asyncio.run(client._run_cli("status", "--json"))
    assert raised.value.returncode == 23


def test_status_cli_fallback_does_not_duplicate_subcommand(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    client = GasCityClient(city_path=tmp_path)
    arguments: list[str] = []

    async def unavailable(*args, **kwargs):
        raise _ApiUnavailable("not available")

    async def fallback(category, *args):
        arguments.extend(args)
        return "{}"

    monkeypatch.setattr(client, "_request_api", unavailable)
    monkeypatch.setattr(client, "_run_cli", fallback)
    asyncio.run(client.status())
    assert arguments == ["status", "--json"]


def test_schema_mismatch_is_typed(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    client = GasCityClient(city_path=tmp_path)

    async def unavailable(*args, **kwargs):
        raise _ApiUnavailable("not available")

    async def malformed(*args, **kwargs):
        return "[]"

    monkeypatch.setattr(client, "_request_api", unavailable)
    monkeypatch.setattr(client, "_run_cli", malformed)
    with pytest.raises(GasCitySchemaError):
        asyncio.run(client.status())
