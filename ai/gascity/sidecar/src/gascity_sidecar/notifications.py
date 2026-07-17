"""Notification dedupe primitive persisted in the sidecar database."""

from __future__ import annotations

from .state import StateStore


class NotificationDedupe:
    def __init__(self, store: StateStore):
        self.store = store

    def claim(self, key: str) -> bool:
        return self.store.claim_notification(key)
