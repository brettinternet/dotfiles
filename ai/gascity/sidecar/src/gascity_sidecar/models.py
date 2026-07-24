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


class MarkdownPreviewRequest(BaseModel):
    """Request to inspect a Markdown backlog source."""

    model_config = ConfigDict(extra="forbid")

    source_path: str = Field(min_length=1)
    relative_path: str | None = None


class MarkdownTaskRecord(BaseModel):
    """Portable task summary returned by Markdown preview."""

    model_config = ConfigDict(extra="forbid")

    id: str
    title: str
    actionable: bool
    external_ref: str


class MarkdownImportRequest(MarkdownPreviewRequest):
    """Request to materialize one Markdown task into Beads."""

    task_id: str = Field(min_length=1)


class DependencyRecord(BaseModel):
    """Result of reconciling one imported task dependency."""

    model_config = ConfigDict(extra="forbid")

    dependency_id: str
    action: str
    bead_id: str | None = None


class MarkdownImportRecord(BaseModel):
    """Result of materializing a Markdown task into Beads."""

    model_config = ConfigDict(extra="forbid")

    task_id: str
    title: str
    external_ref: str
    bead_id: str
    action: str
    created: bool
    dependencies: list[DependencyRecord] = Field(default_factory=list)


class WorkflowDispatchRequest(BaseModel):
    """Request to admit and dispatch one Gas City workflow."""

    model_config = ConfigDict(extra="forbid")

    bead_id: str = Field(min_length=1)
    external_source_ref: str = Field(min_length=1)
    target: str = Field(min_length=1)
    provider: str = Field(min_length=1)
    max_repair_attempts: int | None = Field(default=None, ge=0, le=100)


class WorkflowDispatchRecord(BaseModel):
    """Admission and Gas City result for a dispatched workflow."""

    model_config = ConfigDict(extra="forbid")

    bead_id: str
    external_source_ref: str
    target: str
    provider: str
    max_repair_attempts: int
    result: Any