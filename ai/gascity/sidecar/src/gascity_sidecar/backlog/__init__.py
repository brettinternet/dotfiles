"""Backlog source interfaces and adapters."""

from .base import (
    BacklogError,
    BacklogSource,
    DuplicateTaskIdError,
    MalformedBacklogError,
    MissingDependencyError,
    ReadOnlySourceError,
    Task,
    TaskState,
    TaskNotFoundError,
)
from .markdown import fingerprint_section, slugify_title
from .markdown import MarkdownBacklog, normalize_section_body, parse_markdown
from .beads import (
    AmbiguousExternalRefError,
    BeadsClient,
    BeadsCommandError,
    BeadsError,
    DependencyResult,
    MaterializationResult,
    import_task,
    source_metadata,
)


__all__ = [
    "BacklogError",
    "BacklogSource",
    "DuplicateTaskIdError",
    "MalformedBacklogError",
    "MissingDependencyError",
    "ReadOnlySourceError",
    "Task",
    "TaskNotFoundError",
    "TaskState",
    "MarkdownBacklog",
    "normalize_section_body",
    "parse_markdown",
    "fingerprint_section",
    "slugify_title",
    "AmbiguousExternalRefError",
    "BeadsClient",
    "BeadsCommandError",
    "BeadsError",
    "DependencyResult",
    "MaterializationResult",
    "import_task",
    "source_metadata",
]
