"""Admission policy and manual provider-usage boundary for the sidecar."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any, Protocol, runtime_checkable

from .models import CodexBudgetMode, DesiredState


CODEX_PROVIDERS = frozenset({"codex", "omp", "omp-personal"})


@runtime_checkable
class UsageReader(Protocol):
    """Provider usage signal boundary; no quota retrieval is performed here."""

    def read(self, provider: str) -> Mapping[str, Any] | None:
        """Return a manually supplied usage signal, if one exists."""


class ManualUsageReader:
    """In-memory usage signal for operators and future provider integrations."""

    def __init__(self, initial: Mapping[str, Mapping[str, Any]] | None = None):
        self._usage: dict[str, dict[str, Any]] = {
            provider: dict(value) for provider, value in (initial or {}).items()
        }

    def read(self, provider: str) -> Mapping[str, Any] | None:
        value = self._usage.get(provider)
        return dict(value) if value is not None else None

    def set(self, provider: str, value: Mapping[str, Any] | None) -> None:
        if value is None:
            self._usage.pop(provider, None)
        else:
            self._usage[provider] = dict(value)


class AdmissionController:
    def __init__(self, state: DesiredState):
        self.state = state

    @staticmethod
    def is_codex_provider(provider: str) -> bool:
        return provider.strip().lower() in CODEX_PROVIDERS

    def allows(self, provider: str) -> bool:
        """Return whether a new run for ``provider`` may be admitted."""
        if self.state.paused:
            return False
        if self.is_codex_provider(provider):
            return self.state.codex_budget_mode not in {
                CodexBudgetMode.CRITICAL,
                CodexBudgetMode.PAUSED,
            }
        return True

    allows_provider = allows

    def allows_new_work(self, provider: str | None = None) -> bool:
        """Compatibility wrapper for dispatchers without provider metadata."""
        if provider is None:
            return (
                not self.state.paused
                and self.state.codex_budget_mode is not CodexBudgetMode.PAUSED
            )
        return self.allows(provider)

    def priority(self, provider: str) -> int:
        """Lower numbers are lower priority under conserve mode."""
        if (
            self.state.codex_budget_mode is CodexBudgetMode.CONSERVE
            and self.is_codex_provider(provider)
        ):
            return -1
        return 0
