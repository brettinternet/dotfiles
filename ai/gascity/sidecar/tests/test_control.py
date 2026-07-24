from __future__ import annotations

import asyncio
import tomllib
from pathlib import Path
from typing import Any

import pytest

from gascity_sidecar.admission import AdmissionController, ManualUsageReader
from gascity_sidecar.config import Settings
from gascity_sidecar.control import ControlPlane
from gascity_sidecar.models import CodexBudgetMode, DesiredState
from gascity_sidecar.state import StateStore


class FakeClient:
    city_name = "city"

    def __init__(self, snapshots: list[dict[str, Any]] | None = None) -> None:
        self.snapshots = list(snapshots or [{"sessions": [], "workflows": []}])
        self.snapshot_calls = 0
        self.reload_calls = 0
        self.stop_calls = 0
        self.kill_calls = 0

    async def snapshot(self) -> dict[str, Any]:
        self.snapshot_calls += 1
        if len(self.snapshots) > 1:
            return self.snapshots.pop(0)
        return self.snapshots[0]

    async def status(self) -> dict[str, Any]:
        return await self.snapshot()

    async def reload(self) -> None:
        self.reload_calls += 1

    async def stop(self) -> None:
        self.stop_calls += 1

    async def kill(self) -> None:
        self.kill_calls += 1


def run(awaitable):
    return asyncio.run(awaitable)


def make_plane(
    tmp_path: Path,
    client: FakeClient | None = None,
    *,
    drain_poll_interval_seconds: float = 0.001,
    drain_timeout_seconds: float = 0.1,
) -> tuple[ControlPlane, StateStore, FakeClient, Path]:
    city_path = tmp_path / "city"
    city_path.mkdir()
    settings = Settings(
        city_path=city_path,
        state_db_path=tmp_path / "state.sqlite3",
        drain_poll_interval_seconds=drain_poll_interval_seconds,
        drain_timeout_seconds=drain_timeout_seconds,
    )
    store = StateStore(settings.state_db_path)
    fake = client or FakeClient()
    return ControlPlane(store, fake, settings), store, fake, city_path


def test_pause_blocks_admission_and_resume_unblocks(tmp_path: Path) -> None:
    plane, store, _, _ = make_plane(tmp_path)

    paused = run(plane.pause())
    assert paused.new_state.paused is True
    assert not AdmissionController(store.load_desired_state()).allows("codex")
    assert not AdmissionController(store.load_desired_state()).allows("other")

    resumed = run(plane.resume())
    assert resumed.new_state.paused is False
    controller = AdmissionController(store.load_desired_state())
    assert controller.allows("codex")
    assert controller.allows("other")


@pytest.mark.parametrize(
    ("mode", "codex_allowed"),
    [
        (CodexBudgetMode.NORMAL, True),
        (CodexBudgetMode.CONSERVE, True),
        (CodexBudgetMode.CRITICAL, False),
        (CodexBudgetMode.PAUSED, False),
    ],
)
def test_provider_aware_budget_admission_matrix(
    mode: CodexBudgetMode, codex_allowed: bool
) -> None:
    controller = AdmissionController(DesiredState(codex_budget_mode=mode))
    for provider in ("codex", "omp", "omp-personal"):
        assert controller.allows(provider) is codex_allowed
    assert controller.allows("other-provider") is True
    if mode is CodexBudgetMode.CONSERVE:
        assert controller.priority("codex") < controller.priority("other-provider")

    globally_paused = AdmissionController(
        DesiredState(paused=True, codex_budget_mode=mode)
    )
    for provider in ("codex", "omp", "omp-personal", "other-provider"):
        assert globally_paused.allows(provider) is False


def test_drain_waits_for_settled_snapshots_without_stop_or_kill(tmp_path: Path) -> None:
    client = FakeClient(
        [
            {"sessions": [{"id": "session-1"}], "workflows": [{"id": "workflow-1"}]},
            {"sessions": [], "workflows": []},
        ]
    )
    plane, store, client, _ = make_plane(tmp_path, client)

    result = run(plane.drain())

    assert result.new_state.paused is True
    assert client.kill_calls == 0
    assert client.snapshot_calls == 2
    assert client.stop_calls == 0
    assert store.load_desired_state().paused is True


def test_drain_timeout_reports_not_settled_without_killing(tmp_path: Path) -> None:
    client = FakeClient([{"sessions": [{"id": "active"}], "workflows": []}])
    plane, _, client, _ = make_plane(
        tmp_path,
        client,
        drain_poll_interval_seconds=0.001,
        drain_timeout_seconds=0.02,
    )

    result = run(plane.drain())

    assert any("not settled" in warning.lower() for warning in result.warnings)
    assert client.snapshot_calls >= 1
    assert client.kill_calls == 0
    assert client.stop_calls == 0


def test_concurrency_writes_sidecar_only_and_reloads(tmp_path: Path) -> None:
    plane, _, client, city_path = make_plane(tmp_path)
    (city_path / "city.toml").write_text(
        'include = ["city.sidecar.toml"]\n', encoding="utf-8"
    )
    human_config = city_path / "city.local.toml"
    human_config.write_text("human_setting = true\n", encoding="utf-8")

    configured = run(plane.set_concurrency(64))
    sidecar_config = city_path / "city.sidecar.toml"
    assert sidecar_config.is_file()
    assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 64}
    }
    assert human_config.read_text(encoding="utf-8") == "human_setting = true\n"
    assert not (city_path / ".gc" / "city.local.toml").exists()
    assert configured.new_state.desired_concurrency == 64

    conserved = run(plane.set_codex_budget_mode(CodexBudgetMode.CONSERVE))
    assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 1}
    }
    conserve_warning = " ".join(conserved.warnings).lower()
    assert "workspace cap" in conserve_warning
    assert "v1.3.5" in conserve_warning
    assert "per-provider" in conserve_warning
    assert "non-codex" in conserve_warning

    restored = run(plane.set_codex_budget_mode(CodexBudgetMode.NORMAL))
    assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 64}
    }
    assert restored.new_state.desired_concurrency == 64
    assert client.reload_calls == 3


@pytest.mark.parametrize(
    "mode", [CodexBudgetMode.CRITICAL, CodexBudgetMode.PAUSED]
)
def test_leaving_conserve_for_admission_only_modes_restores_workspace_cap(
    tmp_path: Path, mode: CodexBudgetMode
) -> None:
    plane, _, client, city_path = make_plane(tmp_path)
    (city_path / "city.toml").write_text(
        'include = ["city.sidecar.toml"]\n', encoding="utf-8"
    )
    sidecar_config = city_path / "city.sidecar.toml"

    run(plane.set_concurrency(4))
    run(plane.set_codex_budget_mode(CodexBudgetMode.CONSERVE))
    assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 1}
    }

    result = run(plane.set_codex_budget_mode(mode))

    assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 4}
    }
    assert result.gc_operation_performed == "reload"
    assert any("admission only" in warning for warning in result.warnings)


def test_concurrency_under_conserve_warns_that_cap_stays_at_one(
    tmp_path: Path,
) -> None:
    plane, _, _, city_path = make_plane(tmp_path)
    (city_path / "city.toml").write_text(
        'include = ["city.sidecar.toml"]\n', encoding="utf-8"
    )
    sidecar_config = city_path / "city.sidecar.toml"
    run(plane.set_codex_budget_mode(CodexBudgetMode.CONSERVE))

    result = run(plane.set_concurrency(8))

    assert result.new_state.desired_concurrency == 8
    assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 1}
    }
    warning = " ".join(result.warnings).lower()
    assert "conserve" in warning
    assert "after leaving conserve" in warning

    restored = run(plane.set_codex_budget_mode(CodexBudgetMode.NORMAL))
    assert restored.gc_operation_performed == "reload"
    assert tomllib.loads(sidecar_config.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 8}
    }


@pytest.mark.parametrize("value", [0, 65, "1", 1.0, True])
def test_concurrency_rejects_invalid_values(tmp_path: Path, value: object) -> None:
    plane, _, client, city_path = make_plane(tmp_path)
    (city_path / "city.toml").write_text(
        'include = ["city.sidecar.toml"]\n', encoding="utf-8"
    )

    with pytest.raises(ValueError):
        run(plane.set_concurrency(value))
    assert client.reload_calls == 0
    assert not (city_path / "city.sidecar.toml").exists()


@pytest.mark.parametrize("value", [0, 100])
def test_repair_attempts_accept_bounds(tmp_path: Path, value: int) -> None:
    plane, _, _, _ = make_plane(tmp_path)

    result = run(plane.set_max_repair_attempts(value))

    assert result.new_state.default_max_repair_attempts == value
    assert result.applies_to == "future"


@pytest.mark.parametrize("value", [-1, 101, "3", 3.0, True])
def test_repair_attempts_reject_invalid_values(tmp_path: Path, value: object) -> None:
    plane, store, _, _ = make_plane(tmp_path)
    before = store.load_desired_state()

    with pytest.raises(ValueError):
        run(plane.set_max_repair_attempts(value))
    assert store.load_desired_state() == before


def test_successful_controls_serialize_exactly_five_reporting_fields(
    tmp_path: Path,
) -> None:
    client = FakeClient()
    plane, _, _, city_path = make_plane(tmp_path, client)
    (city_path / "city.toml").write_text(
        'include = ["city.sidecar.toml"]\n', encoding="utf-8"
    )
    methods = [
        lambda: plane.pause(),
        lambda: plane.resume(),
        lambda: plane.drain(),
        lambda: plane.set_concurrency(2),
        lambda: plane.set_max_repair_attempts(4),
        lambda: plane.set_codex_budget_mode(CodexBudgetMode.CONSERVE),
        lambda: plane.emergency_stop("city"),
    ]
    expected = {
        "previous_state",
        "new_state",
        "gc_operation_performed",
        "applies_to",
        "warnings",
    }

    for method in methods:
        result = run(method())
        assert set(result.model_dump(mode="json")) == expected


def test_emergency_stop_requires_exact_city_name(tmp_path: Path) -> None:
    plane, _, client, _ = make_plane(tmp_path)

    with pytest.raises(ValueError):
        run(plane.emergency_stop("City"))
    assert client.stop_calls == 0

    result = run(plane.emergency_stop("city"))
    assert client.stop_calls == 1
    assert set(result.model_dump(mode="json")) == {
        "previous_state",
        "new_state",
        "gc_operation_performed",
        "applies_to",
        "warnings",
    }


def test_manual_usage_reader_has_no_real_quota_source() -> None:
    reader = ManualUsageReader()

    assert reader.read("codex") is None
    reader.set("codex", {"remaining": 3, "limit": 10})
    assert reader.read("codex") == {"remaining": 3, "limit": 10}
    assert reader.read("other-provider") is None


def test_concurrency_persists_state_when_reload_fails(tmp_path: Path) -> None:
    class FailingReloadClient(FakeClient):
        async def reload(self) -> None:
            self.reload_calls += 1
            raise RuntimeError("expected reload failure")

    client = FailingReloadClient()
    plane, store, _, city_path = make_plane(tmp_path, client)
    (city_path / "city.toml").write_text(
        'include = ["city.sidecar.toml"]\n', encoding="utf-8"
    )

    result = run(plane.set_concurrency(2))

    assert set(result.model_dump(mode="json")) == {
        "previous_state",
        "new_state",
        "gc_operation_performed",
        "applies_to",
        "warnings",
    }
    assert result.gc_operation_performed is None
    warning = " ".join(result.warnings).lower()
    assert "config persisted" in warning
    assert "reload failed" in warning or "reload pending" in warning
    assert store.load_desired_state().desired_concurrency == 2
    assert tomllib.loads(
        (city_path / "city.sidecar.toml").read_text(encoding="utf-8")
    ) == {"workspace": {"max_active_sessions": 2}}
    assert client.reload_calls == 1


@pytest.mark.parametrize(
    ("mode", "expected_limit"),
    [
        (CodexBudgetMode.CONSERVE, 1),
        (CodexBudgetMode.NORMAL, 2),
    ],
)
def test_budget_mode_persists_state_when_reload_fails(
    tmp_path: Path, mode: CodexBudgetMode, expected_limit: int
) -> None:
    class FailingReloadClient(FakeClient):
        async def reload(self) -> None:
            self.reload_calls += 1
            raise RuntimeError("expected reload failure")

    client = FailingReloadClient()
    plane, store, _, city_path = make_plane(tmp_path, client)
    store.save_desired_state(
        DesiredState(desired_concurrency=2, codex_budget_mode=CodexBudgetMode.CRITICAL)
    )
    (city_path / "city.toml").write_text(
        'include = ["city.sidecar.toml"]\n', encoding="utf-8"
    )

    result = run(plane.set_codex_budget_mode(mode))

    assert result.gc_operation_performed is None
    warning = " ".join(result.warnings).lower()
    assert "config persisted" in warning
    assert "reload failed" in warning or "reload pending" in warning
    desired = store.load_desired_state()
    assert desired.codex_budget_mode is mode
    assert tomllib.loads(
        (city_path / "city.sidecar.toml").read_text(encoding="utf-8")
    ) == {"workspace": {"max_active_sessions": expected_limit}}
    assert client.reload_calls == 1
