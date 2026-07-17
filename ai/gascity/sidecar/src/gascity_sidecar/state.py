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
                "ON CONFLICT(id) DO UPDATE SET sequence = excluded.sequence",
                (sequence,),
            )
        return sequence

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
