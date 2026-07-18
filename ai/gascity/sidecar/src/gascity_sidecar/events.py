"""Mapping and durable processing for Gas City events."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterable, Iterable, Mapping
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from .state import StateStore

_LOG = logging.getLogger(__name__)


class EventKind(StrEnum):
    WORKFLOW_STARTED = "workflow_started"
    WORKFLOW_COMPLETED = "workflow_completed"
    WORKFLOW_FAILED = "workflow_failed"
    WORKFLOW_BLOCKED = "workflow_blocked"
    HUMAN_INPUT_REQUIRED = "human_input_required"
    RETRY_EXHAUSTED = "retry_exhausted"
    CONTROLLER_UNHEALTHY = "controller_unhealthy"
    CONSUMER_LAGGING = "consumer_lagging"


class InternalEvent(BaseModel):
    """Stable, intentionally small event shape exposed by the sidecar API."""

    model_config = ConfigDict(extra="forbid")

    identity: str
    sequence: int = Field(ge=0)
    kind: EventKind
    occurred_at: str
    source_type: str
    subject: str | None = None
    message: str | None = None
    payload: Any = None

    @property
    def event_type(self) -> str:
        return self.kind.value


_EVENT_ALIASES: dict[EventKind, frozenset[str]] = {
    EventKind.WORKFLOW_STARTED: frozenset(
        {
            "workflow.started",
            "workflow.start",
            "run.started",
            "dispatch.started",
            "formula.started",
            "order.fired",
            "convoy.created",
            "convoy.started",
        }
    ),
    EventKind.WORKFLOW_COMPLETED: frozenset(
        {
            "workflow.completed",
            "workflow.complete",
            "run.completed",
            "dispatch.completed",
            "formula.completed",
            "order.completed",
            "convoy.closed",
        }
    ),
    EventKind.WORKFLOW_FAILED: frozenset(
        {"workflow.failed", "run.failed", "dispatch.failed", "formula.failed", "convoy.failed"}
    ),
    EventKind.WORKFLOW_BLOCKED: frozenset(
        {"workflow.blocked", "workflow.waiting", "run.blocked", "dispatch.blocked", "formula.blocked", "convoy.blocked"}
    ),
    EventKind.HUMAN_INPUT_REQUIRED: frozenset(
        {"human.input_required", "human_input_required", "input.required", "workflow.input_required"}
    ),
    EventKind.RETRY_EXHAUSTED: frozenset(
        {"retry.exhausted", "retry_exhausted", "workflow.retry_exhausted", "workflow.retries_exhausted"}
    ),
    EventKind.CONTROLLER_UNHEALTHY: frozenset(
        {"controller.unhealthy", "controller.stopped", "controller.failed", "controller.crashed", "controller.error"}
    ),
    EventKind.CONSUMER_LAGGING: frozenset(
        {"consumer.lagging", "consumer.lag", "events.lagging", "event_consumer.lagging"}
    ),
}

def _normalise_type(value: object) -> str:
    return str(value).strip().lower().replace("-", "_").replace(" ", "_")


_WORKFLOW_ISSUE_TYPES = frozenset({"convoy", "formula", "run", "workflow"})


def _bead_payload(payload: Any) -> Mapping[str, Any] | None:
    if not isinstance(payload, Mapping):
        return None
    bead = payload.get("bead", payload)
    return bead if isinstance(bead, Mapping) else None


def _kind_for(raw_type: str, payload: Any) -> EventKind | None:
    normalized = _normalise_type(raw_type).replace("_", ".")
    if normalized in {"workflow.failed", "run.failed"} and isinstance(payload, Mapping):
        if payload.get("retry_exhausted") or payload.get("retries_exhausted"):
            return EventKind.RETRY_EXHAUSTED
    bead = _bead_payload(payload)
    if normalized in {"bead.created", "bead.closed", "bead.updated"} and bead is not None:
        issue_type = _normalise_type(bead.get("issue_type"))
        if issue_type in _WORKFLOW_ISSUE_TYPES:
            if normalized == "bead.created":
                return EventKind.WORKFLOW_STARTED
            if normalized == "bead.closed":
                metadata = bead.get("metadata")
                reason = _normalise_type(metadata.get("close_reason")) if isinstance(metadata, Mapping) else ""
                if any(marker in reason for marker in ("fail", "error", "exception", "timeout")):
                    return EventKind.WORKFLOW_FAILED
                return EventKind.WORKFLOW_COMPLETED
            status = _normalise_type(bead.get("status"))
            if status in {"blocked", "waiting", "blocked_on_dependency"}:
                return EventKind.WORKFLOW_BLOCKED
    for kind, aliases in _EVENT_ALIASES.items():
        if normalized in {_normalise_type(alias).replace("_", ".") for alias in aliases}:
            return kind
    return None


def map_event(raw: Mapping[str, Any]) -> InternalEvent | None:
    """Map one API/JSONL DTO, returning ``None`` for unknown or malformed input."""

    if not isinstance(raw, Mapping):
        _LOG.warning("skipping malformed Gas City event: not an object")
        return None
    sequence = raw.get("seq", raw.get("sequence"))
    raw_type = raw.get("type")
    occurred_at = raw.get("ts", raw.get("timestamp"))
    if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 0:
        _LOG.warning("skipping malformed Gas City event: invalid sequence")
        return None
    if not isinstance(raw_type, str) or not raw_type.strip():
        _LOG.warning("skipping malformed Gas City event at sequence %s: invalid type", sequence)
        return None
    if not isinstance(occurred_at, str) or not occurred_at.strip():
        _LOG.warning("skipping malformed Gas City event at sequence %s: invalid timestamp", sequence)
        return None
    payload = raw.get("payload")
    kind = _kind_for(raw_type, payload)
    if kind is None:
        _LOG.info("skipping unknown Gas City event type %s", raw_type)
        return None
    identity = str(raw.get("id") or raw.get("event_id") or f"{sequence}:{raw_type}")
    subject = raw.get("subject")
    message = raw.get("message")
    return InternalEvent(
        identity=identity,
        sequence=sequence,
        kind=kind,
        occurred_at=occurred_at,
        source_type=raw_type,
        subject=subject if isinstance(subject, str) else None,
        message=message if isinstance(message, str) else None,
        payload=payload,
    )


class EventMapper:
    """Object-oriented facade retained for callers that prefer an injectable mapper."""

    map = staticmethod(map_event)


class EventCheckpoint:
    def __init__(self, store: StateStore):
        self.store = store

    def load(self) -> int:
        return self.store.load_event_checkpoint()

    def save(self, sequence: int) -> int:
        return self.store.save_event_checkpoint(sequence)


class EventProcessor:
    """Process replayable raw events without allowing one bad event to stop the stream."""

    def __init__(self, store: StateStore, notifier: Any | None = None, *, recent_limit: int = 100):
        from .notifications import NullNotifier, NotificationDedupe

        self.store = store
        self.notifier = notifier or NullNotifier()
        self.dedupe = NotificationDedupe(store)
        self.recent_limit = recent_limit

    def _deliver(self, event: InternalEvent) -> None:
        try:
            self.notifier.notify(event)
        except Exception:
            _LOG.warning("notification failed for event %s; continuing", event.identity)
        finally:
            self.store.complete_notification(event.identity)

    def process_pending(self) -> None:
        for payload in self.store.load_pending_notifications():
            try:
                event = InternalEvent.model_validate(payload)
            except Exception:
                _LOG.warning("skipping malformed pending notification")
                continue
            if self.dedupe.claim(event.identity):
                self._deliver(event)
            else:
                self.store.complete_notification(event.identity)


    def process(self, raw: Mapping[str, Any]) -> InternalEvent | None:
        sequence = raw.get("seq", raw.get("sequence")) if isinstance(raw, Mapping) else None
        if isinstance(sequence, int) and not isinstance(sequence, bool) and sequence <= self.store.load_event_checkpoint():
            return None
        event = map_event(raw)
        if event is None:
            if isinstance(sequence, int) and not isinstance(sequence, bool) and sequence >= 0:
                self.store.save_event_checkpoint(sequence)
            return None
        event_payload = event.model_dump(mode="json")
        self.store.stage_notification(event_payload)
        self.store.record_internal_event(event_payload, max_events=self.recent_limit)
        if self.dedupe.claim(event.identity):
            self._deliver(event)
        return event

    async def consume(self, events: AsyncIterable[Mapping[str, Any]] | Iterable[Mapping[str, Any]]) -> None:
        if hasattr(events, "__aiter__"):
            async for raw in events:  # type: ignore[union-attr]
                self.process(raw)
        else:
            for raw in events:  # type: ignore[union-attr]
                self.process(raw)

    async def run(self, client: Any) -> None:
        self.process_pending()
        stream = getattr(client, "stream_events", None)
        if stream is None:
            _LOG.info("Gas City client has no event stream; event consumer disabled")
            return
        try:
            await self.consume(stream(after=self.store.load_event_checkpoint()))
        except asyncio.CancelledError:
            raise
        except Exception:
            _LOG.warning("Gas City event stream stopped; sidecar remains available")
