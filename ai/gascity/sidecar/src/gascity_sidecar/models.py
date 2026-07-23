"""Typed API and durable-state models for the sidecar."""

from __future__ import annotations
from enum import StrEnum

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class CodexBudgetMode(StrEnum):
    NORMAL = "normal"
    CONSERVE = "conserve"
    CRITICAL = "critical"
    PAUSED = "paused"


class DesiredState(BaseModel):
    """Sidecar-owned policy state persisted in SQLite."""

    model_config = ConfigDict(extra="forbid")

    paused: bool = False
    desired_concurrency: int = Field(default=1, ge=1, le=64)
    default_max_repair_attempts: int = Field(default=3, ge=0, le=100)
    codex_budget_mode: CodexBudgetMode = CodexBudgetMode.NORMAL
    active_backlog_sources: list[str] = Field(default_factory=list)
    last_processed_event_sequence: int = Field(default=0, ge=0)


class ControlResult(BaseModel):
    """The complete, truthful result of a sidecar control mutation."""

    model_config = ConfigDict(extra="forbid")

    previous_state: DesiredState
    new_state: DesiredState
    gc_operation_performed: str | None = None
    applies_to: Literal["immediate", "future"]
    warnings: list[str] = Field(default_factory=list)


class HealthResponse(BaseModel):
    status: str
    gc: str


class StatusResponse(BaseModel):
    desired: DesiredState
    gc: dict[str, Any]
    sessions: list[Any] = Field(default_factory=list)
    workflows: list[Any] = Field(default_factory=list)
