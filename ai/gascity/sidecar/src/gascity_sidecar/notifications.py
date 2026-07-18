"""Notification interfaces and the optional Pushover notifier."""

from __future__ import annotations

import logging
import os
from collections.abc import Mapping
from typing import Any, Protocol
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .events import InternalEvent
from .state import StateStore

_LOG = logging.getLogger(__name__)


class Notifier(Protocol):
    def notify(self, event: InternalEvent) -> None:
        """Deliver one internal event, or raise if delivery failed."""


class NullNotifier:
    """Disabled notifier used when Pushover credentials are not configured."""

    enabled = False

    def notify(self, event: InternalEvent) -> None:
        return None


class PushoverNotifier:
    endpoint = "https://api.pushover.net/1/messages.json"

    def __init__(
        self,
        app_token: str | None = None,
        user_key: str | None = None,
        *,
        timeout: float = 5.0,
    ):
        self.app_token = app_token or os.environ.get("PUSHOVER_APP_TOKEN")
        self.user_key = user_key or os.environ.get("PUSHOVER_USER_KEY")
        self.timeout = timeout
        self.enabled = bool(self.app_token and self.user_key)

    @classmethod
    def from_environment(cls) -> "PushoverNotifier":
        return cls()

    def notify(self, event: InternalEvent) -> None:
        if not self.enabled:
            _LOG.info("Pushover disabled; notification skipped for event %s", event.identity)
            return None
        title = f"Gas City: {event.kind.value.replace('_', ' ')}"
        message = event.subject or event.message or event.source_type
        payload = urlencode(
            {"token": self.app_token, "user": self.user_key, "title": title, "message": message}
        ).encode()
        request = Request(
            self.endpoint,
            data=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        # Do not include request data or exception text in logs: either may contain a secret.
        with urlopen(request, timeout=self.timeout) as response:
            if response.status < 200 or response.status >= 300:
                raise OSError(f"Pushover returned HTTP {response.status}")


class NotificationDedupe:
    def __init__(self, store: StateStore):
        self.store = store

    def claim(self, key: str) -> bool:
        return self.store.claim_notification(key)

    def claim_event(self, event: InternalEvent) -> bool:
        return self.claim(event.identity)
