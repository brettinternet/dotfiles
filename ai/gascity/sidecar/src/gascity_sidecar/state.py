"""SQLite persistence for sidecar-owned state."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

from .models import DesiredState


class StateStore:
    """Small stdlib-only SQLite store; each operation uses a short connection."""

    def __init__(self, path: str | Path):
        self.path = str(path)
        if self.path != ":memory:":
            Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=5)
        connection.row_factory = sqlite3.Row
        return connection

    def _initialize(self) -> None:
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS desired_state (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    payload TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS event_checkpoint (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    sequence INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS notification_dedupe (
                    notification_key TEXT PRIMARY KEY,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS recent_events (
                    identity TEXT PRIMARY KEY,
                    sequence INTEGER NOT NULL,
                    payload TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                """
            )

    def load_desired_state(self) -> DesiredState:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT payload FROM desired_state WHERE id = 1"
            ).fetchone()
        if row is None:
            return DesiredState()
        return DesiredState.model_validate(json.loads(row["payload"]))

    def save_desired_state(self, state: DesiredState) -> DesiredState:
        payload = json.dumps(state.model_dump(mode="json"), sort_keys=True)
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO desired_state(id, payload) VALUES (1, ?) "
                "ON CONFLICT(id) DO UPDATE SET payload = excluded.payload",
                (payload,),
            )
        return state

    def load_event_checkpoint(self) -> int:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT sequence FROM event_checkpoint WHERE id = 1"
            ).fetchone()
        return int(row["sequence"]) if row else 0

    def save_event_checkpoint(self, sequence: int) -> int:
        if sequence < 0:
            raise ValueError("event sequence cannot be negative")
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO event_checkpoint(id, sequence) VALUES (1, ?) "
                "ON CONFLICT(id) DO UPDATE SET sequence = MAX(sequence, excluded.sequence)",
                (sequence,),
            )
        return self.load_event_checkpoint()

    def record_internal_event(self, event: dict[str, Any], *, max_events: int = 100) -> None:
        """Persist an internal event and advance its cursor atomically."""
        if max_events < 1:
            raise ValueError("max_events must be positive")
        identity = event.get("identity")
        sequence = event.get("sequence")
        if not isinstance(identity, str) or not identity:
            raise ValueError("internal event identity is required")
        if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 0:
            raise ValueError("internal event sequence must be non-negative")
        payload = json.dumps(event, sort_keys=True)
        with self._connect() as connection:
            connection.execute(
                "INSERT OR IGNORE INTO recent_events(identity, sequence, payload) VALUES (?, ?, ?)",
                (identity, sequence, payload),
            )
            connection.execute(
                "INSERT INTO event_checkpoint(id, sequence) VALUES (1, ?) "
                "ON CONFLICT(id) DO UPDATE SET sequence = MAX(sequence, excluded.sequence)",
                (sequence,),
            )
            connection.execute(
                "DELETE FROM recent_events WHERE identity IN ("
                "SELECT identity FROM recent_events ORDER BY sequence DESC, identity DESC "
                "LIMIT -1 OFFSET ?)",
                (max_events,),
            )

    def load_recent_events(self, limit: int = 100) -> list[dict[str, Any]]:
        if limit < 1:
            return []
        with self._connect() as connection:
            rows = connection.execute(
                "SELECT payload FROM recent_events ORDER BY sequence DESC, identity DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [json.loads(row["payload"]) for row in rows]

    def claim_notification(self, notification_key: str) -> bool:
        """Return true only for the first occurrence of a notification key."""
        with self._connect() as connection:
            result = connection.execute(
                "INSERT OR IGNORE INTO notification_dedupe(notification_key) VALUES (?)",
                (notification_key,),
            )
        return result.rowcount == 1

    # Explicit aliases make the ownership of these stores clear to callers.
    get_desired_state = load_desired_state
    set_desired_state = save_desired_state
    get_event_checkpoint = load_event_checkpoint
    set_event_checkpoint = save_event_checkpoint
    mark_notification_sent = claim_notification


SQLiteStateStore = StateStore
