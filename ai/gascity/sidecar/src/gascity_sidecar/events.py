"""Durable event cursor access used by later event consumers."""

from __future__ import annotations

from .state import StateStore


class EventCheckpoint:
    def __init__(self, store: StateStore):
        self.store = store

    def load(self) -> int:
        return self.store.load_event_checkpoint()

    def save(self, sequence: int) -> int:
        return self.store.save_event_checkpoint(sequence)
