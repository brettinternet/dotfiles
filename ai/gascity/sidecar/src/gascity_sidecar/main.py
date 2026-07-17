"""Process entrypoint for the sidecar HTTP server."""

from __future__ import annotations

from typing import Any

from .api import create_app
from .config import Settings, validate_bind
from .logging_setup import configure_logging


def run_server(
    *,
    settings: Settings | None = None,
    host: str | None = None,
    port: int | None = None,
    allow_non_loopback: bool | None = None,
) -> None:
    import uvicorn

    settings = settings or Settings()
    actual_host = host or settings.bind_host
    actual_port = port or settings.bind_port
    allow = (
        settings.allow_non_loopback_bind
        if allow_non_loopback is None
        else allow_non_loopback
    )
    validate_bind(actual_host, allow_non_loopback=allow)
    configure_logging(settings.log_level)
    uvicorn.run(create_app(settings), host=actual_host, port=actual_port, log_config=None)


def application(**overrides: Any):
    """ASGI factory useful to process managers and focused tests."""
    return create_app(Settings(**overrides))
