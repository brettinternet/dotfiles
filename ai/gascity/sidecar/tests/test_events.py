from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from gascity_sidecar.api import create_app
from gascity_sidecar.gascity import GasCityClient
from gascity_sidecar.events import EventKind, EventProcessor, map_event
from gascity_sidecar.notifications import PushoverNotifier
from gascity_sidecar.state import StateStore
from gascity_sidecar.config import Settings


TS = "2026-07-17T20:00:00Z"


def raw(seq: int, event_type: str, **extra: object) -> dict[str, object]:
    return {"seq": seq, "type": event_type, "ts": TS, **extra}


def test_event_mapping_and_tolerance() -> None:
    assert map_event(raw(1, "workflow.started")).kind == EventKind.WORKFLOW_STARTED
    assert map_event(raw(2, "workflow.failed", payload={"retry_exhausted": True})).kind == EventKind.RETRY_EXHAUSTED
    assert (
        map_event(raw(3, "bead.created", payload={"bead": {"issue_type": "convoy"}})).kind
        == EventKind.WORKFLOW_STARTED
    )
    assert (
        map_event(
            raw(
                4,
                "bead.closed",
                payload={"bead": {"issue_type": "convoy", "metadata": {"close_reason": "workflow failed"}}},
            )
        ).kind
        == EventKind.WORKFLOW_FAILED
    )
    assert (
        map_event(raw(5, "bead.updated", payload={"bead": {"issue_type": "convoy", "status": "blocked"}})).kind
        == EventKind.WORKFLOW_BLOCKED
    )
    assert map_event(raw(6, "bead.closed", payload={"bead": {"issue_type": "task"}})) is None
    assert map_event(raw(7, "convoy.closed")).kind == EventKind.WORKFLOW_COMPLETED
    assert map_event(raw(8, "unknown.event")) is None
    assert map_event({"seq": 9, "type": "workflow.started"}) is None
    assert map_event({"seq": "bad", "type": "workflow.started", "ts": TS}) is None


def test_checkpoint_resume_and_recent_events(tmp_path: Path) -> None:
    store = StateStore(tmp_path / "state.sqlite3")
    processor = EventProcessor(store)
    processor.process(raw(1, "workflow.started", subject="alpha"))
    processor.process(raw(1, "workflow.started", subject="alpha"))
    processor.process(raw(2, "unknown.event"))
    assert store.load_event_checkpoint() == 2
    assert [event["sequence"] for event in store.load_recent_events()] == [1]


def test_notification_failure_isolated_and_deduped_after_restart(tmp_path: Path) -> None:
    store_path = tmp_path / "state.sqlite3"
    sent: list[str] = []

    class FailingNotifier:
        def notify(self, event):
            sent.append(event.identity)
            raise RuntimeError("network failure")

    first = EventProcessor(StateStore(store_path), FailingNotifier())
    first.process(raw(7, "workflow.completed", id="event-7"))
    second = EventProcessor(StateStore(store_path), FailingNotifier())
    second.process(raw(7, "workflow.completed", id="event-7"))
    assert sent == ["event-7"]


def test_pushover_unset_is_disabled(monkeypatch) -> None:
    monkeypatch.delenv("PUSHOVER_APP_TOKEN", raising=False)
    monkeypatch.delenv("PUSHOVER_USER_KEY", raising=False)
    assert not PushoverNotifier.from_environment().enabled


def test_event_and_gc_read_endpoints(tmp_path: Path) -> None:
    class Client:
        async def status(self):
            return {"ok": True, "sessions": [{"name": "worker"}], "workflows": [{"id": "run-1"}]}

        async def workflows(self):
            return [{"id": "run-1"}]

        async def workers(self):
            return [{"name": "worker"}]

    settings = Settings(state_db_path=tmp_path / "state.sqlite3")
    store = StateStore(settings.state_db_path)
    EventProcessor(store).process(raw(1, "workflow.started", subject="run-1"))
    with TestClient(create_app(settings, gc_client=Client())) as client:
        assert client.get("/events").json()[0]["kind"] == "workflow_started"
        assert client.get("/workflows").json() == [{"id": "run-1"}]
        assert client.get("/workers").json() == [{"name": "worker"}]

def test_malformed_api_event_items_are_logged(caplog) -> None:
    event = raw(1, "workflow.started")
    assert GasCityClient._event_items([event, "malformed"]) == [event]
    assert "malformed Gas City event item" in caplog.text


def test_pending_notification_survives_crash_after_dedupe_claim(tmp_path: Path) -> None:
    store_path = tmp_path / "state.sqlite3"

    class CrashStore(StateStore):
        def claim_notification(self, notification_key: str) -> bool:
            claimed = super().claim_notification(notification_key)
            assert claimed
            raise KeyboardInterrupt

    first = EventProcessor(CrashStore(store_path))
    try:
        first.process(raw(7, "workflow.completed", id="event-7"))
    except KeyboardInterrupt:
        pass
    else:
        raise AssertionError("expected simulated process crash")

    sent: list[str] = []

    class Notifier:
        def notify(self, event) -> None:
            sent.append(event.identity)

    second = EventProcessor(StateStore(store_path), Notifier())
    second.process_pending()
    second.process_pending()
    second.process(raw(7, "workflow.completed", id="event-7"))
    assert sent == ["event-7"]
