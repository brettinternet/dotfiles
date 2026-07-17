"""Read-only admission policy primitive for sidecar-owned desired state."""

from __future__ import annotations

from .models import DesiredState


class AdmissionController:
    def __init__(self, state: DesiredState):
        self.state = state

    def allows_new_work(self) -> bool:
        return not self.state.paused and self.state.codex_budget_mode.value != "paused"
