"""Common models and interface for sidecar backlog sources.

This module deliberately has no transport or web-framework dependencies.  Sources
are read-only during preview/materialization; a future adapter may implement
writeback explicitly.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any


class BacklogError(Exception):
    """Base class for expected, typed backlog failures."""


class MalformedBacklogError(BacklogError):
    """The source does not conform to the adapter grammar."""


class DuplicateTaskIdError(BacklogError):
    """Two sections resolve to the same stable task ID."""

    def __init__(self, task_id: str, *, titles: tuple[str, ...] = ()) -> None:
        self.task_id = task_id
        self.titles = titles
        detail = f"duplicate task id {task_id!r}"
        if titles:
            detail += f" in sections {', '.join(titles)!r}"
        super().__init__(detail)


class MissingDependencyError(BacklogError):
    """A task declares a dependency that is absent from the source."""

    def __init__(self, task_id: str, dependency_id: str) -> None:
        self.task_id = task_id
        self.dependency_id = dependency_id
        super().__init__(
            f"task {task_id!r} depends on missing task {dependency_id!r}"
        )


class TaskNotFoundError(BacklogError):
    """The requested task ID is not present in the source."""

    def __init__(self, task_id: str) -> None:
        self.task_id = task_id
        super().__init__(f"task {task_id!r} was not found")


class ReadOnlySourceError(BacklogError):
    """The source has no write-back operation in this adapter version."""


@dataclass(frozen=True, slots=True)
class Task:
    """A normalized task exposed by a backlog source."""

    id: str
    title: str
    body: str
    external_ref: str
    fingerprint: str
    dependencies: tuple[str, ...]
    done: bool
    actionable: bool
    section_number: int

    @property
    def source_ref(self) -> str:
        """Alias used by consumers that call external refs source refs."""
        return self.external_ref


@dataclass(frozen=True, slots=True)
class TaskState:
    """State accepted by the source interface's future writeback operation."""

    done: bool
    metadata: dict[str, Any] | None = None


class BacklogSource(ABC):
    """Interface implemented by every sidecar backlog source.

    ``preview`` and ``materialize`` are intentionally separate operations even
    though the Markdown v1 adapter performs both as pure reads.  ``writeback``
    is explicit so callers cannot mistake import for a source mutation.
    """

    @abstractmethod
    def preview(self) -> list[Task]:
        """Return all source tasks in source order without mutating the source."""
        raise NotImplementedError

    @abstractmethod
    def materialize(self, task_id: str) -> Task:
        """Return one task by stable ID without mutating the source."""
        raise NotImplementedError

    @abstractmethod
    def writeback(self, task_id: str, state: TaskState) -> None:
        """Apply state to the source, if the adapter supports explicit writeback."""
        raise NotImplementedError
