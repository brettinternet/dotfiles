"""Explicit Markdown-to-Beads materialization service.

The Markdown source adapter remains read-only.  This module owns all subprocess
calls and is intentionally usable without the sidecar HTTP application.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import subprocess
from typing import Any, Sequence

from .base import BacklogError, Task


class BeadsError(BacklogError):
    """Base class for expected Beads command failures."""


class BeadsCommandError(BeadsError):
    """A Beads subprocess exited unsuccessfully or returned invalid JSON."""

    def __init__(self, command: Sequence[str], returncode: int, stderr: str) -> None:
        self.command = tuple(command)
        self.returncode = returncode
        self.stderr = stderr
        detail = stderr.strip() or f"exit status {returncode}"
        super().__init__(f"bd {' '.join(command[1:])} failed: {detail}")


class AmbiguousExternalRefError(BeadsError):
    """More than one bead has the same exact external reference."""

    def __init__(self, external_ref: str, count: int) -> None:
        self.external_ref = external_ref
        self.count = count
        super().__init__(f"external ref {external_ref!r} matched {count} beads; refusing to choose")


@dataclass(frozen=True, slots=True)
class DependencyResult:
    dependency_id: str
    action: str
    bead_id: str | None = None


@dataclass(frozen=True, slots=True)
class MaterializationResult:
    task_id: str
    title: str
    external_ref: str
    bead_id: str
    action: str
    dependencies: tuple[DependencyResult, ...] = ()

    def as_dict(self) -> dict[str, Any]:
        return {
            "task_id": self.task_id,
            "title": self.title,
            "external_ref": self.external_ref,
            "bead_id": self.bead_id,
            "action": self.action,
            "dependencies": [
                {
                    "dependency_id": dep.dependency_id,
                    "action": dep.action,
                    **({"bead_id": dep.bead_id} if dep.bead_id else {}),
                }
                for dep in self.dependencies
            ],
        }


class BeadsClient:
    """Small, list-based subprocess client for the installed ``bd`` CLI."""

    def __init__(
        self,
        command: Sequence[str] = ("bd",),
        *,
        cwd: str | Path | None = None,
        env: dict[str, str] | None = None,
    ) -> None:
        self.command = tuple(command)
        self.cwd = str(cwd) if cwd is not None else None
        self.env = {**os.environ, **env} if env is not None else None

    def _run(self, args: Sequence[str], *, json_output: bool = False) -> Any:
        command = [*self.command, *args]
        completed = subprocess.run(
            command,
            cwd=self.cwd,
            env=self.env,
            check=False,
            capture_output=True,
            text=True,
        )
        if completed.returncode:
            raise BeadsCommandError(command, completed.returncode, completed.stderr)
        if not json_output:
            return completed.stdout
        try:
            return json.loads(completed.stdout)
        except json.JSONDecodeError as exc:
            raise BeadsCommandError(command, completed.returncode, "invalid JSON output") from exc

    def find_external_ref(self, external_ref: str) -> dict[str, Any] | None:
        # bd 1.1.0 requires a positional query even with --external-contains.
        # Every normal Beads issue ID contains '-', making this a broad query.
        payload = self._run(
            [
                "search",
                "-",
                "--external-contains",
                external_ref,
                "--status",
                "all",
                "--json",
            ],
            json_output=True,
        )
        if isinstance(payload, dict):
            records = [payload]
        elif isinstance(payload, list):
            records = payload
        else:
            raise BeadsCommandError(self.command + ("search",), 0, "unexpected JSON result")
        matches = [record for record in records if isinstance(record, dict) and record.get("external_ref") == external_ref]
        if len(matches) > 1:
            raise AmbiguousExternalRefError(external_ref, len(matches))
        return matches[0] if matches else None

    def create(self, task: Task, metadata: dict[str, str]) -> dict[str, Any]:
        payload = self._run(
            [
                "create",
                "--title",
                task.title,
                "--description",
                task.body,
                "--external-ref",
                task.external_ref,
                "--metadata",
                json.dumps(metadata, sort_keys=True, separators=(",", ":")),
                "--json",
            ],
            json_output=True,
        )
        return self._record(payload)

    def update(self, task: Task, metadata: dict[str, str]) -> dict[str, Any]:
        payload = self._run(
            [
                "update",
                "--external-ref",
                task.external_ref,
                "--title",
                task.title,
                "--description",
                task.body,
                "--metadata",
                json.dumps(metadata, sort_keys=True, separators=(",", ":")),
                "--json",
            ],
            json_output=True,
        )
        return self._record(payload)

    def add_dependency(self, bead_id: str, dependency_bead_id: str) -> None:
        self._run(["dep", "add", bead_id, dependency_bead_id, "--json"], json_output=True)

    def show(self, bead_id: str) -> dict[str, Any]:
        payload = self._run(["show", bead_id, "--json"], json_output=True)
        return self._record(payload)

    @staticmethod
    def _record(payload: Any) -> dict[str, Any]:
        if isinstance(payload, dict):
            return payload
        if isinstance(payload, list) and len(payload) == 1 and isinstance(payload[0], dict):
            return payload[0]
        raise BeadsCommandError(("bd",), 0, "unexpected JSON result")


def source_metadata(task: Task) -> dict[str, str]:
    """Build the stable source metadata required on every materialized bead."""
    prefix, separator, location = task.external_ref.partition(":")
    if prefix != "md" or not separator:
        raise BeadsError(f"unsupported external ref {task.external_ref!r}")
    source_path, marker, source_id = location.rpartition("#")
    if not marker or not source_path or not source_id:
        raise BeadsError(f"malformed Markdown external ref {task.external_ref!r}")
    return {
        "source_kind": "markdown",
        "source_path": source_path,
        "source_id": source_id,
        "source_title": task.title,
        "source_fingerprint": task.fingerprint,
    }


def import_task(source: Any, task_id: str, beads: BeadsClient) -> MaterializationResult:
    """Materialize one task and wire dependencies whose beads already exist."""
    task = source.materialize(task_id)
    metadata = source_metadata(task)
    existing = beads.find_external_ref(task.external_ref)
    if existing is None:
        record = beads.create(task, metadata)
        action = "created"
    else:
        existing_metadata = existing.get("metadata")
        if not isinstance(existing_metadata, dict):
            existing_metadata = {}
        if (
            existing.get("title") == task.title
            and all(existing_metadata.get(key) == value for key, value in metadata.items())
        ):
            record = existing
            action = "skipped"
        else:
            record = beads.update(task, metadata)
            action = "updated"
    bead_id = record.get("id")
    if not isinstance(bead_id, str) or not bead_id:
        raise BeadsError(f"bd returned no bead id for {task.external_ref!r}")

    current = beads.show(bead_id) if task.dependencies else {}
    current_dependencies = {
        dependency.get("id")
        for dependency in current.get("dependencies", [])
        if isinstance(dependency, dict)
    }

    tasks_by_id = {candidate.id.casefold(): candidate for candidate in source.preview()}
    dependency_results: list[DependencyResult] = []
    for dependency_id in task.dependencies:
        dependency = tasks_by_id.get(dependency_id.casefold())
        if dependency is None:
            dependency_results.append(DependencyResult(dependency_id, "skipped"))
            continue
        dependency_bead = beads.find_external_ref(dependency.external_ref)
        if dependency_bead is None:
            dependency_results.append(DependencyResult(dependency_id, "skipped"))
            continue
        dependency_bead_id = dependency_bead.get("id")
        if not isinstance(dependency_bead_id, str) or not dependency_bead_id:
            dependency_results.append(DependencyResult(dependency_id, "skipped"))
            continue
        if dependency_bead_id in current_dependencies:
            dependency_results.append(DependencyResult(dependency_id, "skipped", dependency_bead_id))
            continue
        beads.add_dependency(bead_id, dependency_bead_id)
        current_dependencies.add(dependency_bead_id)
        dependency_results.append(DependencyResult(dependency_id, "wired", dependency_bead_id))
    return MaterializationResult(
        task_id=task.id,
        title=task.title,
        external_ref=task.external_ref,
        bead_id=bead_id,
        action=action,
        dependencies=tuple(dependency_results),
    )
