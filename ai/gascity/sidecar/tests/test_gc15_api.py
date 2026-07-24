from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from gascity_sidecar.api import create_app
from gascity_sidecar.gascity import GasCityError
from gascity_sidecar.backlog.beads import AmbiguousExternalRefError
from gascity_sidecar.config import Settings
from gascity_sidecar.models import CodexBudgetMode, DesiredState
from gascity_sidecar.state import StateStore


class FakeBeadsClient:
    """In-memory Beads boundary used by HTTP tests; no subprocesses are allowed."""

    def __init__(self) -> None:
        self.records: dict[str, dict[str, Any]] = {}
        self.by_id: dict[str, dict[str, Any]] = {}
        self.ambiguous_external_ref: str | None = None
        self.calls: list[tuple[Any, ...]] = []
        self._next_id = 1

    def find_external_ref(self, external_ref: str) -> dict[str, Any] | None:
        self.calls.append(("find_external_ref", external_ref))
        if external_ref == self.ambiguous_external_ref:
            raise AmbiguousExternalRefError(external_ref, 2)
        record = self.records.get(external_ref)
        return deepcopy(record) if record is not None else None

    def create(self, task: Any, metadata: dict[str, str]) -> dict[str, Any]:
        self.calls.append(("create", task.id, metadata))
        bead_id = f"bead-{self._next_id}"
        self._next_id += 1
        record = {
            "id": bead_id,
            "title": task.title,
            "external_ref": task.external_ref,
            "metadata": dict(metadata),
            "dependencies": [],
        }
        self.records[task.external_ref] = record
        self.by_id[bead_id] = record
        return deepcopy(record)

    def update(self, task: Any, metadata: dict[str, str]) -> dict[str, Any]:
        self.calls.append(("update", task.id, metadata))
        record = self.records[task.external_ref]
        record.update(title=task.title, metadata=dict(metadata))
        return deepcopy(record)

    def show(self, bead_id: str) -> dict[str, Any]:
        self.calls.append(("show", bead_id))
        return deepcopy(self.by_id[bead_id])

    def add_dependency(self, bead_id: str, dependency_bead_id: str) -> None:
        self.calls.append(("add_dependency", bead_id, dependency_bead_id))
        dependency = self.by_id[dependency_bead_id]
        self.by_id[bead_id]["dependencies"].append(
            {"id": dependency_bead_id, "external_ref": dependency["external_ref"]}
        )

    def remove_dependency(self, bead_id: str, dependency_bead_id: str) -> None:
        self.calls.append(("remove_dependency", bead_id, dependency_bead_id))
        self.by_id[bead_id]["dependencies"] = [
            dependency
            for dependency in self.by_id[bead_id]["dependencies"]
            if dependency.get("id") != dependency_bead_id
        ]


class FakeGasCityClient:
    """Async dispatch boundary that records exact arguments and returns JSON."""

    city_name = "gc15-test-city"
    def __init__(self) -> None:
        self.dispatch_calls: list[tuple[str, str, int]] = []
        self.reload_calls = 0
        self.dispatch_error: GasCityError | None = None

    async def dispatch_workflow(
        self, target: str, bead_id: str, max_repair_attempts: int
    ) -> dict[str, Any]:
        if self.dispatch_error is not None:
            raise self.dispatch_error
        self.dispatch_calls.append((target, bead_id, max_repair_attempts))
        return {
            "success": True,
            "target": target,
            "bead_id": bead_id,
            "workflow_id": "workflow-gc15",
        }

    async def reload(self) -> None:
        self.reload_calls += 1

    async def status(self) -> dict[str, Any]:
        return {"ok": True, "running": True}


@pytest.fixture
def api_fixture(tmp_path: Path) -> tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient]:
    city_path = tmp_path / "city"
    city_path.mkdir()
    state_store = StateStore(tmp_path / "state.sqlite3")
    beads = FakeBeadsClient()
    gc_client = FakeGasCityClient()
    settings = Settings(city_path=city_path, state_db_path=tmp_path / "state.sqlite3")
    app = create_app(
        settings,
        state_store=state_store,
        gc_client=gc_client,
        beads_client=beads,
    )
    with TestClient(app) as client:
        yield client, city_path, state_store, beads, gc_client


def write_source(city_path: Path, name: str = "backlog.md", *, duplicate: bool = False) -> Path:
    source = city_path / name
    if duplicate:
        source.write_text(
            "## First\n<!-- id: duplicate-task -->\n\n"
            "## Second\n<!-- id: duplicate-task -->\n",
            encoding="utf-8",
        )
    else:
        source.write_text(
            "## Importable task\n<!-- id: importable-task -->\nBody\n\n"
            "## Already complete\n<!-- id: complete-task -->\nStatus: done\n",
            encoding="utf-8",
        )
    return source


def assert_typed_error(response: Any, status_code: int, code: str) -> None:
    assert response.status_code == status_code
    payload = response.json()
    assert set(payload) >= {"code", "detail"}
    assert payload["code"] == code
    assert isinstance(payload["detail"], str)
    assert payload["detail"]


@pytest.mark.parametrize(
    ("source_path", "expected_status", "expected_code"),
    [
        ("/tmp/not-relative.md", 422, "invalid_source_path"),
        ("../outside.md", 422, "invalid_source_path"),
        ("missing.md", 404, "source_not_found"),
    ],
)
def test_preview_rejects_bad_source_paths(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
    source_path: str,
    expected_status: int,
    expected_code: str,
) -> None:
    client = api_fixture[0]
    response = client.post(
        "/backlogs/markdown/preview",
        json={"source_path": source_path, "relative_path": None},
    )
    assert_typed_error(response, expected_status, expected_code)


def test_preview_returns_typed_task_records(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, city_path, *_ = api_fixture
    write_source(city_path)

    response = client.post(
        "/backlogs/markdown/preview",
        json={"source_path": "backlog.md", "relative_path": "docs/backlog.md"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert isinstance(payload, list)
    assert payload
    assert payload[0] == {
        "id": "importable-task",
        "title": "Importable task",
        "actionable": True,
        "external_ref": "md:docs/backlog.md#importable-task",
    }
    assert all(set(task) == {"id", "title", "actionable", "external_ref"} for task in payload)
    assert payload[1]["actionable"] is False

def test_preview_reports_malformed_source_as_backlog_error(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, city_path, *_ = api_fixture
    (city_path / "malformed.md").write_text("##\n", encoding="utf-8")

    response = client.post(
        "/backlogs/markdown/preview",
        json={"source_path": "malformed.md", "relative_path": None},
    )

    assert_typed_error(response, 422, "backlog_error")


def test_import_reports_unknown_task_id_with_typed_error(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, city_path, *_ = api_fixture
    write_source(city_path)

    response = client.post(
        "/backlogs/markdown/import",
        json={"source_path": "backlog.md", "relative_path": None, "task_id": "unknown"},
    )

    assert_typed_error(response, 404, "task_not_found")


def test_import_reports_duplicate_task_id_with_typed_error(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, city_path, *_ = api_fixture
    write_source(city_path, duplicate=True)

    response = client.post(
        "/backlogs/markdown/import",
        json={"source_path": "backlog.md", "relative_path": None, "task_id": "duplicate-task"},
    )

    assert_typed_error(response, 409, "duplicate_task_id")


def test_import_reports_ambiguous_external_ref_with_typed_error(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, city_path, _, beads, _ = api_fixture
    write_source(city_path)
    beads.ambiguous_external_ref = "md:backlog.md#importable-task"

    response = client.post(
        "/backlogs/markdown/import",
        json={"source_path": "backlog.md", "relative_path": None, "task_id": "importable-task"},
    )

    assert_typed_error(response, 409, "ambiguous_external_ref")


def test_import_is_idempotent_and_never_changes_source_bytes(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, city_path, *_ = api_fixture
    source = write_source(city_path)
    before = source.read_bytes()
    request = {
        "source_path": "backlog.md",
        "relative_path": None,
        "task_id": "importable-task",
    }

    first = client.post("/backlogs/markdown/import", json=request)
    second = client.post("/backlogs/markdown/import", json=request)

    assert first.status_code == 200
    assert second.status_code == 200
    first_payload = first.json()
    second_payload = second.json()
    assert first_payload["task_id"] == second_payload["task_id"] == "importable-task"
    assert first_payload["title"] == second_payload["title"] == "Importable task"
    assert first_payload["external_ref"] == second_payload["external_ref"] == (
        "md:backlog.md#importable-task"
    )
    assert first_payload["bead_id"] == second_payload["bead_id"]
    assert first_payload["action"] == "created"
    assert first_payload["created"] is True
    assert second_payload["action"] == "skipped"
    assert second_payload["created"] is False
    assert isinstance(first_payload["dependencies"], list)
    assert source.read_bytes() == before


def dispatch_request(
    *,
    bead_id: str = "bead-1",
    external_source_ref: str = "md:backlog.md#importable-task",
    target: str = "fixture/gc.intake",
    provider: str = "codex",
    max_repair_attempts: int | None = None,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "bead_id": bead_id,
        "external_source_ref": external_source_ref,
        "target": target,
        "provider": provider,
    }
    if max_repair_attempts is not None:
        request["max_repair_attempts"] = max_repair_attempts
    return request


def test_dispatch_refuses_when_paused(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, _, state_store, _, gc_client = api_fixture
    state_store.save_desired_state(DesiredState(paused=True))

    response = client.post("/workflows/dispatch", json=dispatch_request())

    assert_typed_error(response, 409, "admission_refused")
    assert gc_client.dispatch_calls == []


def test_dispatch_refuses_omp_in_critical_mode_but_allows_non_codex_provider(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, _, state_store, _, gc_client = api_fixture
    state_store.save_desired_state(DesiredState(codex_budget_mode=CodexBudgetMode.CRITICAL))

    refused = client.post(
        "/workflows/dispatch",
        json=dispatch_request(provider="omp", bead_id="bead-omp"),
    )
    allowed = client.post(
        "/workflows/dispatch",
        json=dispatch_request(provider="github", bead_id="bead-github"),
    )

    assert_typed_error(refused, 409, "admission_refused")
    assert allowed.status_code == 200
    assert gc_client.dispatch_calls == [("fixture/gc.intake", "bead-github", 3)]


def test_resume_allows_dispatch_and_preserves_explicit_provider_and_source_ref(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, _, _, _, gc_client = api_fixture
    paused = client.post("/control/pause")
    assert paused.status_code == 200
    refused = client.post(
        "/workflows/dispatch",
        json=dispatch_request(provider="github", bead_id="bead-resume"),
    )
    assert_typed_error(refused, 409, "admission_refused")

    resumed = client.post("/control/resume")
    allowed = client.post(
        "/workflows/dispatch",
        json=dispatch_request(
            bead_id="bead-resume",
            external_source_ref="md:custom/source.md#resume-task",
            target="fixture/gc.planner",
            provider="github",
            max_repair_attempts=7,
        ),
    )

    assert resumed.status_code == 200
    assert allowed.status_code == 200
    payload = allowed.json()
    assert payload["bead_id"] == "bead-resume"
    assert payload["external_source_ref"] == "md:custom/source.md#resume-task"
    assert payload["target"] == "fixture/gc.planner"
    assert payload["provider"] == "github"
    assert payload["max_repair_attempts"] == 7
    assert payload["result"]["success"] is True
    assert gc_client.dispatch_calls == [("fixture/gc.planner", "bead-resume", 7)]

def test_dispatch_maps_gascity_failures_to_typed_502(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, _, _, _, gc_client = api_fixture
    gc_client.dispatch_error = GasCityError("controller unavailable")

    response = client.post("/workflows/dispatch", json=dispatch_request())

    assert_typed_error(response, 502, "gascity_error")
    assert gc_client.dispatch_calls == []


def test_dispatch_uses_requested_and_desired_default_repair_attempts(
    api_fixture: tuple[TestClient, Path, StateStore, FakeBeadsClient, FakeGasCityClient],
) -> None:
    client, _, state_store, _, gc_client = api_fixture
    state_store.save_desired_state(DesiredState(default_max_repair_attempts=9))

    requested = client.post(
        "/workflows/dispatch",
        json=dispatch_request(bead_id="bead-requested", max_repair_attempts=1),
    )
    defaulted = client.post(
        "/workflows/dispatch",
        json=dispatch_request(bead_id="bead-defaulted"),
    )

    assert requested.status_code == 200
    assert defaulted.status_code == 200
    assert requested.json()["max_repair_attempts"] == 1
    assert defaulted.json()["max_repair_attempts"] == 9
    assert gc_client.dispatch_calls == [
        ("fixture/gc.intake", "bead-requested", 1),
        ("fixture/gc.intake", "bead-defaulted", 9),
    ]
