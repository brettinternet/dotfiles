"""Pure Markdown v1 backlog parser and identity adapter."""

from __future__ import annotations

import hashlib
import re
import unicodedata
from dataclasses import replace
from pathlib import Path
from typing import Iterable

from .base import (
    BacklogSource,
    DuplicateTaskIdError,
    MalformedBacklogError,
    MissingDependencyError,
    ReadOnlySourceError,
    Task,
    TaskNotFoundError,
    TaskState,
)

_SECTION_RE = re.compile(r"^##[ \t]+(.+?)\s*$")
_DEPENDS_RE = re.compile(r"^\s*Depends on:\s*(.*?)\s*$", re.IGNORECASE)
_STATUS_RE = re.compile(r"^\s*Status:\s*(.*?)\s*$", re.IGNORECASE)
_ID_RE = re.compile(r"<!--[ \t]*id:[ \t]*([A-Za-z0-9][A-Za-z0-9._:-]*)[ \t]*-->")
_ID_MARKER_RE = re.compile(r"<!--[ \t]*id:")
_ID_VALUE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")


def normalize_section_body(body: str) -> str:
    """Normalize a section body for deterministic comparison and hashing.

    Line endings become LF, trailing horizontal whitespace is removed, and
    leading/trailing blank lines are discarded.  Content and its internal blank
    lines otherwise remain unchanged.
    """

    lines = body.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    lines = [line.rstrip(" \t") for line in lines]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines)


def fingerprint_section(body: str) -> str:
    """Return the SHA-256 fingerprint of a normalized section body."""

    return hashlib.sha256(normalize_section_body(body).encode("utf-8")).hexdigest()


def slugify_title(title: str) -> str:
    """Create the v1 stable ID used when a section has no explicit ID.

    Fixture headings may use ``KEY — human title``; the conventional key is
    already the intended stable slug in that form.
    """

    key_match = re.match(
        r"^([A-Za-z0-9][A-Za-z0-9._:-]*)[ \t]+[—–][ \t]+.+$",
        title,
    )
    identity = key_match.group(1) if key_match else title
    normalized = (
        unicodedata.normalize("NFKD", identity)
        .encode("ascii", "ignore")
        .decode()
    )
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", normalized.lower()).strip("-")
    if not slug:
        raise MalformedBacklogError(f"title {title!r} cannot produce a stable ID")
    return slug


def _section_starts(lines: list[str]) -> list[tuple[int, str]]:
    starts: list[tuple[int, str]] = []
    for number, line in enumerate(lines):
        if line.startswith("##") and not line.startswith("###"):
            match = _SECTION_RE.match(line)
            if match is None:
                raise MalformedBacklogError(
                    f"malformed task heading on line {number + 1}: {line!r}"
                )
            title = match.group(1).strip()
            if not title:
                raise MalformedBacklogError(f"empty task title on line {number + 1}")
            starts.append((number, title))
    return starts


def _parse_id(body_lines: Iterable[str], title: str) -> str:
    matches = []
    marker_count = 0
    for line in body_lines:
        marker_count += len(_ID_MARKER_RE.findall(line))
        matches.extend(_ID_RE.findall(line))
    if marker_count != len(matches):
        raise MalformedBacklogError(f"malformed explicit id in section {title!r}")
    if len(matches) > 1:
        raise MalformedBacklogError(f"multiple explicit ids in section {title!r}")
    return matches[0] if matches else slugify_title(title)


def _parse_dependencies(body_lines: Iterable[str], title: str) -> tuple[str, ...]:
    dependencies: list[str] = []
    for line in body_lines:
        match = _DEPENDS_RE.match(line)
        if match is None:
            continue
        value = match.group(1).strip()
        if not value:
            raise MalformedBacklogError(f"empty dependency list in section {title!r}")
        for dependency in value.split(","):
            dependency_id = dependency.strip()
            if not _ID_VALUE_RE.fullmatch(dependency_id):
                raise MalformedBacklogError(
                    f"malformed dependency {dependency_id!r} in section {title!r}"
                )
            if dependency_id in dependencies:
                raise MalformedBacklogError(
                    f"duplicate dependency {dependency_id!r} in section {title!r}"
                )
            dependencies.append(dependency_id)
    return tuple(dependencies)


def _parse_done(body_lines: Iterable[str], title: str) -> bool:
    statuses: list[str] = []
    for line in body_lines:
        match = _STATUS_RE.match(line)
        if match is not None:
            value = match.group(1).strip().lower()
            if not value:
                raise MalformedBacklogError(f"empty status in section {title!r}")
            statuses.append(value)
    if len(statuses) > 1:
        raise MalformedBacklogError(f"multiple Status lines in section {title!r}")
    return bool(statuses and statuses[0] in {"done", "complete", "completed", "closed"})


def _relative_ref(path: str | Path) -> str:
    candidate = Path(path)
    # Tests and callers often use a temporary absolute path.  Never leak that
    # machine-local prefix into an external ref; retain its configured basename.
    if candidate.is_absolute():
        candidate = Path(candidate.name)
    if not candidate.parts or candidate == Path("."):
        raise MalformedBacklogError("source path must name a Markdown file")
    if any(part in {"", ".", ".."} for part in candidate.parts):
        raise MalformedBacklogError(f"source path must be relative: {path!r}")
    return candidate.as_posix()


def parse_markdown(text: str, *, source_path: str | Path = "backlog.md") -> list[Task]:
    """Parse Markdown text into normalized tasks without touching the filesystem."""
    if not isinstance(text, str):
        raise MalformedBacklogError("Markdown source text must be a string")
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    starts = _section_starts(lines)
    source_ref = _relative_ref(source_path)
    parsed: list[Task] = []
    seen: dict[str, str] = {}
    for section_number, (start, title) in enumerate(starts, start=1):
        end = starts[section_number][0] if section_number < len(starts) else len(lines)
        body = normalize_section_body("\n".join(lines[start + 1 : end]))
        body_lines = body.split("\n") if body else []
        task_id = _parse_id(body_lines, title)
        if task_id in seen:
            raise DuplicateTaskIdError(task_id, titles=(seen[task_id], title))
        seen[task_id] = title
        parsed.append(
            Task(
                id=task_id,
                title=title,
                body=body,
                external_ref=f"md:{source_ref}#{task_id}",
                fingerprint=fingerprint_section(body),
                dependencies=_parse_dependencies(body_lines, title),
                done=_parse_done(body_lines, title),
                actionable=False,
                section_number=section_number,
            )
        )

    by_id = {task.id: task for task in parsed}
    by_fold: dict[str, Task] = {}
    for task in parsed:
        folded = task.id.casefold()
        if folded in by_fold and by_fold[folded].id != task.id:
            raise DuplicateTaskIdError(
                task.id, titles=(by_fold[folded].title, task.title)
            )
        by_fold[folded] = task
    resolved_dependencies: dict[str, tuple[Task, ...]] = {}
    for task in parsed:
        resolved: list[Task] = []
        for dependency_id in task.dependencies:
            dependency = by_id.get(dependency_id) or by_fold.get(dependency_id.casefold())
            if dependency is None:
                raise MissingDependencyError(task.id, dependency_id)
            resolved.append(dependency)
        resolved_dependencies[task.id] = tuple(resolved)
    return [
        replace(
            task,
            actionable=(
                not task.done
                and all(dep.done for dep in resolved_dependencies[task.id])
            ),
        )
        for task in parsed
    ]


class MarkdownBacklog(BacklogSource):
    """Read-only Markdown v1 backlog adapter."""

    def __init__(self, path: str | Path = "backlog.md", *, relative_path: str | Path | None = None):
        self.path = Path(path)
        self.relative_path = _relative_ref(relative_path if relative_path is not None else path)

    @classmethod
    def from_text(
        cls, text: str, *, source_path: str | Path = "backlog.md"
    ) -> "MarkdownBacklogText":
        return MarkdownBacklogText(text, source_path=source_path)

    def preview(self) -> list[Task]:
        return parse_markdown(self.path.read_text(encoding="utf-8"), source_path=self.relative_path)

    def materialize(self, task_id: str) -> Task:
        for task in self.preview():
            if task.id == task_id:
                return task
        raise TaskNotFoundError(task_id)

    def writeback(self, task_id: str, state: TaskState) -> None:
        raise ReadOnlySourceError(
            "Markdown v1 is read-only; writeback is an explicit later adapter operation"
        )


class MarkdownBacklogText(MarkdownBacklog):
    """In-memory variant useful for deterministic parser tests."""

    def __init__(self, text: str, *, source_path: str | Path = "backlog.md"):
        self.path = None
        self._text = text
        self.relative_path = _relative_ref(source_path)

    def preview(self) -> list[Task]:
        return parse_markdown(self._text, source_path=self.relative_path)
