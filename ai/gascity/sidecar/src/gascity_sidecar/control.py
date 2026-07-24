"""Sidecar-owned control operations for admission and safe city changes."""

from __future__ import annotations

import asyncio
import inspect
import os
import tempfile
import tomllib
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .admission import AdmissionController, ManualUsageReader, UsageReader
from .config import Settings
from .models import CodexBudgetMode, ControlResult, DesiredState


class ControlPlane:
    """Coordinate durable sidecar policy with narrowly supported GC operations."""

    def __init__(self, store: Any, client: Any, settings: Settings):
        self.store = store
        self.client = client
        self.settings = settings

    def _load_state(self) -> DesiredState:
        loader = getattr(self.store, "load_desired_state", None)
        if loader is None:
            loader = getattr(self.store, "get_desired_state")
        return loader()

    def _save_state(self, state: DesiredState) -> DesiredState:
        saver = getattr(self.store, "save_desired_state", None)
        if saver is None:
            saver = getattr(self.store, "set_desired_state")
        return saver(state)

    @staticmethod
    def _copy_state(state: DesiredState) -> DesiredState:
        return state.model_copy(deep=True)

    @staticmethod
    def _result(
        previous: DesiredState,
        new: DesiredState,
        operation: str | None,
        applies_to: str,
        warnings: list[str] | None = None,
    ) -> ControlResult:
        return ControlResult(
            previous_state=previous,
            new_state=new,
            gc_operation_performed=operation,
            applies_to=applies_to,
            warnings=list(warnings or []),
        )

    @staticmethod
    def _strict_int(value: Any, name: str) -> int:
        if isinstance(value, bool) or not isinstance(value, int):
            raise ValueError(f"{name} must be an integer")
        return value

    @property
    def _city_path(self) -> Path:
        return Path(self.settings.city_path)

    @property
    def _sidecar_config_path(self) -> Path:
        return self._city_path / "city.sidecar.toml"

    def _sidecar_is_included(self) -> bool:
        city_file = self._city_path / "city.toml"
        try:
            document = tomllib.loads(city_file.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError):
            return False
        include = document.get("include", [])
        if isinstance(include, str):
            include = [include]
        return isinstance(include, list) and "city.sidecar.toml" in include

    @staticmethod
    def _sidecar_text(state: DesiredState) -> str:
        effective_limit = (
            1
            if state.codex_budget_mode is CodexBudgetMode.CONSERVE
            else state.desired_concurrency
        )
        return f"[workspace]\nmax_active_sessions = {effective_limit}\n"

    def _write_sidecar_config(self, state: DesiredState) -> bool:
        """Atomically write valid sidecar-owned TOML and report whether it changed."""
        text = self._sidecar_text(state)
        tomllib.loads(text)
        path = self._sidecar_config_path
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            current = path.read_bytes()
        except FileNotFoundError:
            current = None
        encoded = text.encode("utf-8")
        if current == encoded:
            return False

        temporary_name: str | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="wb",
                dir=path.parent,
                prefix=f".{path.name}.",
                suffix=".tmp",
                delete=False,
            ) as temporary:
                temporary_name = temporary.name
                temporary.write(encoded)
                temporary.flush()
                os.fsync(temporary.fileno())
            os.replace(temporary_name, path)
            temporary_name = None
        finally:
            if temporary_name is not None:
                Path(temporary_name).unlink(missing_ok=True)
        return True

    async def _apply_sidecar_config(
        self, state: DesiredState
    ) -> tuple[str | None, list[str]]:
        changed = self._write_sidecar_config(state)
        if not changed:
            return None, []
        if not self._sidecar_is_included():
            return None, [
                "city.sidecar.toml is not included by city.toml; change remains sidecar-owned admission only"
            ]
        reloader = getattr(self.client, "reload", None)
        if reloader is None:
            return None, [
                "Gas City reload is unavailable; change remains sidecar-owned admission only"
            ]
        result = reloader()
        if inspect.isawaitable(result):
            await result
        return "reload", []

    async def pause(self) -> ControlResult:
        previous = self._load_state()
        new = self._copy_state(previous)
        new.paused = True
        if new != previous:
            self._save_state(new)
        return self._result(
            previous,
            new,
            None,
            "immediate",
            ["pause is sidecar admission only; active sessions are unchanged"],
        )

    async def resume(self) -> ControlResult:
        previous = self._load_state()
        new = self._copy_state(previous)
        new.paused = False
        if new != previous:
            self._save_state(new)
        return self._result(previous, new, None, "immediate")

    @staticmethod
    def _snapshot_settled(snapshot: Any) -> bool:
        if not isinstance(snapshot, Mapping):
            return False
        sessions = snapshot.get("sessions")
        workflows = snapshot.get("workflows")
        status = snapshot.get("status")
        if isinstance(status, Mapping):
            if sessions is None:
                sessions = status.get("sessions", status.get("running_sessions", []))
            if workflows is None:
                workflows = status.get("workflows", status.get("active_workflows", []))
        if sessions is None:
            sessions = []
        if workflows is None:
            workflows = []
        return (
            isinstance(sessions, list)
            and isinstance(workflows, list)
            and not sessions
            and not workflows
        )

    async def drain(self) -> ControlResult:
        pause_result = await self.pause()
        warnings = list(pause_result.warnings)
        interval = float(getattr(self.settings, "drain_poll_interval_seconds", 1.0))
        timeout = float(getattr(self.settings, "drain_timeout_seconds", 30.0))
        deadline = asyncio.get_running_loop().time() + timeout
        settled = False
        snapshotter = getattr(self.client, "snapshot", None)
        if snapshotter is None:
            warnings.append(
                "Gas City snapshots are unavailable; drain could not prove settlement"
            )
        else:
            while True:
                try:
                    snapshot = snapshotter()
                    if inspect.isawaitable(snapshot):
                        snapshot = await snapshot
                    if self._snapshot_settled(snapshot):
                        settled = True
                        break
                except Exception as exc:
                    warnings.append(f"drain snapshot failed: {exc}")
                    break
                remaining = deadline - asyncio.get_running_loop().time()
                if remaining <= 0:
                    break
                await asyncio.sleep(min(interval, remaining))
        if not settled:
            warnings.append(
                "drain timed out or active sessions/workflows are not settled"
            )
        return self._result(
            pause_result.previous_state,
            pause_result.new_state,
            None,
            "immediate",
            warnings,
        )

    async def set_concurrency(self, value: Any) -> ControlResult:
        value = self._strict_int(value, "concurrency")
        if not 1 <= value <= 64:
            raise ValueError("concurrency must be between 1 and 64")
        previous = self._load_state()
        new = self._copy_state(previous)
        new.desired_concurrency = value
        if new != previous:
            self._save_state(new)
        try:
            operation, warnings = await self._apply_sidecar_config(new)
        except Exception as exc:
            operation = None
            warnings = [
                "config persisted but Gas City reload failed/pending; "
                f"retry reload when available: {exc}"
            ]
        if new.codex_budget_mode is CodexBudgetMode.CONSERVE:
            warnings.append(
                "conserve budget mode holds the workspace cap at 1; the new "
                "concurrency takes effect after leaving conserve"
            )
        return self._result(previous, new, operation, "immediate", warnings)

    async def set_max_repair_attempts(self, value: Any) -> ControlResult:
        value = self._strict_int(value, "max repair attempts")
        if not 0 <= value <= 100:
            raise ValueError("max repair attempts must be between 0 and 100")
        previous = self._load_state()
        new = self._copy_state(previous)
        new.default_max_repair_attempts = value
        if new != previous:
            self._save_state(new)
        return self._result(
            previous,
            new,
            None,
            "future",
            ["max repair attempts apply to new dispatches only"],
        )

    async def set_codex_budget_mode(self, value: Any) -> ControlResult:
        if isinstance(value, bool):
            raise ValueError(
                "codex budget mode must be normal, conserve, critical, or paused"
            )
        try:
            mode = (
                value if isinstance(value, CodexBudgetMode) else CodexBudgetMode(value)
            )
        except (TypeError, ValueError) as exc:
            raise ValueError(
                "codex budget mode must be normal, conserve, critical, or paused"
            ) from exc
        previous = self._load_state()
        new = self._copy_state(previous)
        new.codex_budget_mode = mode
        if new != previous:
            self._save_state(new)
        # Apply the sidecar config in every mode: only conserve caps the
        # workspace at 1, so leaving conserve (including for critical/paused)
        # must restore the desired concurrency rather than keep a stale cap.
        try:
            operation, warnings = await self._apply_sidecar_config(new)
        except Exception as exc:
            operation = None
            warnings = [
                "config persisted but Gas City reload failed/pending; "
                f"retry reload when available: {exc}"
            ]
        if mode is CodexBudgetMode.CONSERVE:
            warnings.append(
                "conserve mode uses the supported workspace cap of 1; installed "
                "Gas City v1.3.5 lacks a verified per-provider dynamic cap, so "
                "this also constrains non-Codex sessions"
            )
        elif mode in {CodexBudgetMode.CRITICAL, CodexBudgetMode.PAUSED}:
            warnings.append(
                f"{mode.value} mode is sidecar admission only; installed Gas City suspend behavior is unverified"
            )
        return self._result(previous, new, operation, "immediate", warnings)

    async def emergency_stop(self, confirmation: Any) -> ControlResult:
        city_name = self.client.city_name
        if not isinstance(confirmation, str) or confirmation != city_name:
            raise ValueError("confirmation must exactly match the city name")
        previous = self._load_state()
        stopper = getattr(self.client, "stop", None)
        if stopper is None:
            raise RuntimeError("Gas City stop is unavailable")
        result = stopper()
        if inspect.isawaitable(result):
            await result
        return self._result(previous, self._copy_state(previous), "stop", "immediate")


__all__ = [
    "AdmissionController",
    "ControlPlane",
    "ManualUsageReader",
    "UsageReader",
]
