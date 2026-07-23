"""Environment-backed sidecar configuration."""

from __future__ import annotations

import ipaddress
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration with env > .env > Python defaults precedence."""

    model_config = SettingsConfigDict(
        env_prefix="GC_SIDECAR_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    city_path: Path = Path(".")
    state_db_path: Path = Path(".gc/sidecar.sqlite3")
    bind_host: str = "127.0.0.1"
    bind_port: int = 8787
    allow_non_loopback_bind: bool = False
    gc_api_url: str | None = None
    gc_api_port: int = 8080
    gc_command: str = "gc"
    gc_timeout_seconds: float = 90.0
    drain_poll_interval_seconds: float = 1.0
    drain_timeout_seconds: float = 30.0
    log_level: str = "INFO"

    @field_validator("bind_port", "gc_api_port")
    @classmethod
    def valid_port(cls, value: int) -> int:
        if not 1 <= value <= 65535:
            raise ValueError("port must be between 1 and 65535")
        return value

    @field_validator("gc_timeout_seconds")
    @classmethod
    def valid_timeout(cls, value: float) -> float:
        if value <= 0:
            raise ValueError("gc timeout must be positive")
        return value

    @field_validator("drain_poll_interval_seconds", "drain_timeout_seconds")
    @classmethod
    def valid_drain_setting(cls, value: float, info) -> float:
        if value <= 0:
            raise ValueError(f"{info.field_name} must be positive")
        if info.field_name == "drain_poll_interval_seconds" and value > 60:
            raise ValueError("drain poll interval must be at most 60 seconds")
        if info.field_name == "drain_timeout_seconds" and value > 3600:
            raise ValueError("drain timeout must be at most 3600 seconds")
        return value

    def api_base_url(self) -> str:
        return self.gc_api_url or f"http://127.0.0.1:{self.gc_api_port}"


def validate_bind(host: str, *, allow_non_loopback: bool = False) -> None:
    """Reject public bind addresses unless explicitly opted into them."""

    if allow_non_loopback or host in {"localhost", "ip6-localhost"}:
        return
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        # DNS names cannot be proven loopback without a resolver; only localhost
        # is accepted by default so a typo cannot expose the control plane.
        raise ValueError("sidecar bind host must be loopback unless explicitly allowed")
    if not address.is_loopback:
        raise ValueError("sidecar bind host must be loopback unless explicitly allowed")
