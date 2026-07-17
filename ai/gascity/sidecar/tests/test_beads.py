from __future__ import annotations

import json
import os
from pathlib import Path
import stat
import shutil
import subprocess
import sys

import pytest

from gascity_sidecar.backlog import (
    AmbiguousExternalRefError,
    BeadsClient,
    MarkdownBacklog,
    import_task,
)
from gascity_sidecar.cli import main


ROOT = Path(__file__).parents[2]
FIXTURE = ROOT / "fixtures" / "backlog.md"


FAKE_BD = r'''
import json, os, sys
from pathlib import Path
state_path = Path(os.environ["FAKE_BD_STATE"])
state = json.loads(state_path.read_text()) if state_path.exists() else {"next": 1, "beads": [], "deps": []}
args = sys.argv[1:]
cmd = args[0]
def flag(name):
    i = args.index(name)
    return args[i + 1]
def dump(value):
    print(json.dumps(value))
if cmd == "search":
    ref = flag("--external-contains")
    dump([b for b in state["beads"] if ref.lower() in b.get("external_ref", "").lower()])
elif cmd == "create":
    bead = {"id": f"fake-{state['next']}", "title": flag("--title"),
            "description": flag("--description"), "external_ref": flag("--external-ref"),
            "metadata": json.loads(flag("--metadata"))}
    state["next"] += 1
    state["beads"].append(bead)
    dump(bead)
elif cmd == "update":
    ref = flag("--external-ref")
    bead = next(b for b in state["beads"] if b["external_ref"] == ref)
    bead.update(title=flag("--title"), description=flag("--description"),
                metadata=json.loads(flag("--metadata")))
    dump(bead)
elif cmd == "show":
    bead = next(b for b in state["beads"] if b["id"] == args[1])
    bead = {**bead, "dependencies": [
        next(b for b in state["beads"] if b["id"] == edge["depends_on_id"])
        for edge in state["deps"] if edge["issue_id"] == args[1]
    ]}
    dump([bead])
elif cmd == "dep":
    state["deps"].append({"issue_id": args[2], "depends_on_id": args[3]})
    dump({"status": "added"})
else:
    raise SystemExit(f"unsupported fake command: {cmd}")
state_path.write_text(json.dumps(state))
'''


def fake_client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[BeadsClient, Path]:
    script = tmp_path / "fake-bd.py"
    script.write_text(FAKE_BD)
    script.chmod(script.stat().st_mode | stat.S_IXUSR)
    state = tmp_path / "state.json"
    state.write_text(json.dumps({"next": 1, "beads": [], "deps": []}))
    monkeypatch.setenv("FAKE_BD_STATE", str(state))
    return BeadsClient((sys.executable, str(script)), cwd=tmp_path), state


def test_preview_cli_reports_tasks_without_beads_writes(capsys: pytest.CaptureFixture[str], tmp_path: Path) -> None:
    source = tmp_path / "backlog.md"
    source.write_text("## A Task\nBody\n", encoding="utf-8")
    assert main(["backlog", "preview", "--source", str(source)]) == 0
    assert json.loads(capsys.readouterr().out) == [
        {"actionable": True, "id": "a-task", "title": "A Task"}
    ]


def test_create_skip_update_and_dependency_matrix(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    client, state_path = fake_client(tmp_path, monkeypatch)
    source = MarkdownBacklog(FIXTURE, relative_path="fixtures/backlog.md")

    dependency = import_task(source, "fix-dep", client)
    assert dependency.action == "created"
    first = import_task(source, "fix-review", client)
    assert first.action == "created"
    repeated = import_task(source, "fix-review", client)
    assert repeated.action == "skipped"
    third = import_task(source, "fix-review", client)
    assert third.action == "skipped"
    assert third.bead_id == first.bead_id
    state = json.loads(state_path.read_text())
    assert len(state["beads"]) == 2
    assert state["deps"] == [{"issue_id": first.bead_id, "depends_on_id": dependency.bead_id}]
    metadata = next(b["metadata"] for b in state["beads"] if b["id"] == first.bead_id)
    assert set(metadata) == {
        "source_kind", "source_path", "source_id", "source_title", "source_fingerprint"
    }

    changed = tmp_path / "changed.md"
    text = (
        FIXTURE.read_text(encoding="utf-8")
        .replace("## FIX-REVIEW — Improve the greeting output", "## FIX-REVIEW — Retitle the greeting program")
        .replace("Update the greeting program", "Retitle the greeting program")
    )
    changed.write_text(text, encoding="utf-8")
    updated = import_task(MarkdownBacklog(changed, relative_path="fixtures/backlog.md"), "fix-review", client)
    assert updated.action == "updated"
    state = json.loads(state_path.read_text())
    assert len(state["beads"]) == 2
    bead = next(b for b in state["beads"] if b["id"] == first.bead_id)
    assert bead["title"] == "FIX-REVIEW — Retitle the greeting program"
    assert bead["metadata"]["source_fingerprint"] != metadata["source_fingerprint"]


def test_dependency_wires_when_dependency_is_imported_later(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    client, state_path = fake_client(tmp_path, monkeypatch)
    source = MarkdownBacklog(FIXTURE, relative_path="fixtures/backlog.md")

    dependent = import_task(source, "fix-review", client)
    assert dependent.action == "created"
    assert json.loads(state_path.read_text())["deps"] == []

    dependency = import_task(source, "fix-dep", client)
    state = json.loads(state_path.read_text())
    assert len(state["beads"]) == 2
    assert state["deps"] == [{"issue_id": dependent.bead_id, "depends_on_id": dependency.bead_id}]


def test_ambiguous_external_ref_refuses_to_write(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    client, state_path = fake_client(tmp_path, monkeypatch)
    state_path.write_text(json.dumps({
        "next": 3,
        "beads": [
            {"id": "fake-1", "external_ref": "md:fixtures/backlog.md#fix-dep"},
            {"id": "fake-2", "external_ref": "md:fixtures/backlog.md#fix-dep"},
        ],
        "deps": [],
    }))
    with pytest.raises(AmbiguousExternalRefError):
        import_task(MarkdownBacklog(FIXTURE, relative_path="fixtures/backlog.md"), "fix-dep", client)


def test_cli_entrypoint_preview_smoke(tmp_path: Path) -> None:
    source = tmp_path / "backlog.md"
    source.write_text("## CLI Task\n", encoding="utf-8")
    completed = subprocess.run(
        ["uv", "run", "--project", str(ROOT / "sidecar"), "gascity-sidecar", "backlog", "preview", "--source", str(source)],
        cwd=ROOT.parent,
        capture_output=True,
        text=True,
        check=False,
    )
    assert completed.returncode == 0, completed.stderr
    assert json.loads(completed.stdout)[0]["id"] == "cli-task"


@pytest.mark.skipif(
    os.environ.get("GASCITY_REAL_BD_TEST") != "1",
    reason="set GASCITY_REAL_BD_TEST=1 to run the real Beads integration test",
)
def test_opt_in_real_bd_materialization(tmp_path: Path) -> None:
    if shutil.which("bd") is None:
        pytest.skip("bd is not installed")

    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    env = {
        **os.environ,
        "BD_NON_INTERACTIVE": "1",
        "BEADS_DIR": str(repo / ".beads"),
        "NO_COLOR": "1",
    }
    initialized = subprocess.run(
        [
            "bd",
            "init",
            "--non-interactive",
            "--skip-agents",
            "--skip-hooks",
            "--prefix",
            "fixture",
        ],
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert initialized.returncode == 0, initialized.stderr

    source_path = tmp_path / "backlog.md"
    source_path.write_text("## Real task\n<!-- id: real-task -->\nKeep this deterministic.\n", encoding="utf-8")
    source = MarkdownBacklog(source_path, relative_path="backlog.md")
    client = BeadsClient(cwd=repo, env=env)

    first = import_task(source, "real-task", client)
    repeated = import_task(source, "real-task", client)
    assert first.action == "created"
    assert repeated.action == "skipped"
    assert repeated.bead_id == first.bead_id
    changed_path = tmp_path / "changed.md"
    changed_path.write_text(
        "## Renamed real task\n<!-- id: real-task -->\nChanged deterministically.\n",
        encoding="utf-8",
    )
    updated = import_task(
        MarkdownBacklog(changed_path, relative_path="backlog.md"),
        "real-task",
        client,
    )
    assert updated.action == "updated"
    assert updated.bead_id == first.bead_id

    listed = subprocess.run(
        ["bd", "list", "--all", "--json"],
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert listed.returncode == 0, listed.stderr
    records = json.loads(listed.stdout)
    assert len(records) == 1
    assert records[0]["external_ref"] == "md:backlog.md#real-task"
    assert set(records[0]["metadata"]) == {
        "source_kind",
        "source_path",
        "source_id",
        "source_title",
        "source_fingerprint",
    }
