from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from gascity_sidecar.api import create_app
from gascity_sidecar.config import Settings


@pytest.mark.skipif(
    os.environ.get("GC15_SMOKE") != "1",
    reason="set GC15_SMOKE=1 to run the bounded real fixture-city smoke test",
)
def test_gc15_fixture_preview_import_dispatch_smoke(tmp_path: Path) -> None:
    """Exercise only the HTTP preview/import/dispatch path against the local city.

    The test deliberately does not poll status or wait for a workflow to finish.
    It is opt-in because Beads and Gas City are real external processes here.
    """

    default_city = Path(__file__).resolve().parents[2]
    city_path = Path(os.environ.get("GC15_CITY_PATH", str(default_city))).resolve()
    source_path = os.environ.get(
        "GC15_SOURCE_PATH", ".local/fixture-rig/backlog.md"
    )
    relative_path = os.environ.get("GC15_RELATIVE_PATH", "backlog.md")
    task_id = os.environ.get("GC15_TASK_ID", "fix-independent")
    target = os.environ.get("GC15_TARGET", "fixture/gc.intake")
    provider = os.environ.get("GC15_PROVIDER", "codex")
    requested_attempts = int(os.environ.get("GC15_MAX_REPAIR_ATTEMPTS", "3"))

    source = (city_path / source_path).resolve()
    before = source.read_bytes()
    settings = Settings(
        city_path=city_path,
        state_db_path=tmp_path / "gc15-smoke.sqlite3",
    )
    app = create_app(settings)

    with TestClient(app) as client:
        preview_response = client.post(
            "/backlogs/markdown/preview",
            json={"source_path": source_path, "relative_path": relative_path},
        )
        assert preview_response.status_code == 200
        preview = preview_response.json()
        assert isinstance(preview, list) and preview
        task = next(record for record in preview if record["id"] == task_id)
        assert set(task) == {"id", "title", "actionable", "external_ref"}
        assert task["id"] == task_id

        import_response = client.post(
            "/backlogs/markdown/import",
            json={
                "source_path": source_path,
                "relative_path": relative_path,
                "task_id": task_id,
            },
        )
        assert import_response.status_code == 200
        imported: dict[str, Any] = import_response.json()
        assert {
            "task_id",
            "title",
            "external_ref",
            "bead_id",
            "action",
            "created",
            "dependencies",
        } <= set(imported)
        assert imported["task_id"] == task_id
        assert imported["title"] == task["title"]
        assert imported["external_ref"] == task["external_ref"]
        assert isinstance(imported["bead_id"], str) and imported["bead_id"]
        assert imported["created"] is (imported["action"] == "created")
        assert isinstance(imported["dependencies"], list)

        dispatch_response = client.post(
            "/workflows/dispatch",
            json={
                "bead_id": imported["bead_id"],
                "external_source_ref": imported["external_ref"],
                "target": target,
                "provider": provider,
                "max_repair_attempts": requested_attempts,
            },
        )
        assert dispatch_response.status_code == 200
        dispatched: dict[str, Any] = dispatch_response.json()
        assert dispatched["bead_id"] == imported["bead_id"]
        assert dispatched["external_source_ref"] == imported["external_ref"]
        assert dispatched["target"] == target
        assert dispatched["provider"] == provider
        assert dispatched["max_repair_attempts"] == requested_attempts
        assert isinstance(dispatched["result"], dict)

    assert source.read_bytes() == before
