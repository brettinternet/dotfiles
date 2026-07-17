from __future__ import annotations

import json
from pathlib import Path
import stat
import sys

import pytest

from gascity_sidecar.backlog import (
    BeadStateError,
    BeadsClient,
    DuplicateTaskIdError,
    MarkdownBacklog,
    SourceFingerprintMismatchError,
    TaskNotFoundError,
    import_task,
    writeback_task,
)
FAKE_BD = r'''
import json, os, sys
from pathlib import Path
state = json.loads(Path(os.environ["FAKE_BD_STATE"]).read_text())
args = sys.argv[1:]
if args[0] == "search":
    ref = args[args.index("--external-contains") + 1]
    print(json.dumps([b for b in state["beads"] if b.get("external_ref") == ref]))
elif args[0] == "show":
    bead = next(b for b in state["beads"] if b["id"] == args[1])
    print(json.dumps([bead]))
else:
    raise SystemExit(f"unsupported fake bd command: {args[0]}")
'''


def seeded_source(tmp_path: Path, *, status: str = "closed", fingerprint: str | None = None) -> tuple[MarkdownBacklog, Path]:
    source_path = tmp_path / "backlog.md"
    source_path.write_bytes(
        b"# Header\n\n## Target task\n\nKeep this body.\n\n## Unrelated\n\nLeave these bytes alone.\n"
    )
    source = MarkdownBacklog(source_path, relative_path="fixtures/backlog.md")
    task = source.materialize("target-task")
    record = {
        "id": "fake-1",
        "status": status,
        "title": task.title,
        "description": task.body,
        "external_ref": task.external_ref,
        "metadata": {
            "source_kind": "markdown",
            "source_path": "fixtures/backlog.md",
            "source_id": task.id,
            "source_title": task.title,
            "source_fingerprint": fingerprint or task.fingerprint,
        },
    }
    state_path = tmp_path / "state.json"
    state_path.write_text(json.dumps({"beads": [record]}))
    script_path = tmp_path / "fake-bd.py"
    script_path.write_text(FAKE_BD)
    script_path.chmod(script_path.stat().st_mode | stat.S_IXUSR)
    return source, state_path


def client_for(tmp_path: Path, state_path: Path) -> BeadsClient:
    return BeadsClient((sys.executable, str(tmp_path / "fake-bd.py")), cwd=tmp_path, env={"FAKE_BD_STATE": str(state_path)})


def test_writeback_marks_only_target_section_and_preserves_other_bytes(tmp_path: Path) -> None:
    source, state_path = seeded_source(tmp_path)
    before = source.path.read_bytes()

    result = writeback_task(source, "target-task", client_for(tmp_path, state_path))

    after = source.path.read_bytes()
    assert result.bead_id == "fake-1"
    assert after.startswith(before.split(b"## Target task", 1)[0])
    assert after.split(b"## Unrelated", 1)[1] == before.split(b"## Unrelated", 1)[1]
    assert b"## Target task\nStatus: done\n\nKeep this body." in after
    assert source.materialize("target-task").done is True


@pytest.mark.parametrize(
    ("case", "expected"),
    [
        ("fingerprint", SourceFingerprintMismatchError),
        ("state", BeadStateError),
        ("missing", TaskNotFoundError),
        ("duplicate", DuplicateTaskIdError),
    ],
)
def test_writeback_refusals_are_typed_and_leave_source_unchanged(
    tmp_path: Path, case: str, expected: type[Exception]
) -> None:
    if case == "missing":
        source_path = tmp_path / "backlog.md"
        source_path.write_text("## Present\nBody\n", encoding="utf-8")
        source = MarkdownBacklog(source_path, relative_path="fixtures/backlog.md")
        before = source_path.read_bytes()
        with pytest.raises(expected, match="not found"):
            writeback_task(source, "missing", BeadsClient(("unused-fake-bd",)))
        assert source_path.read_bytes() == before
        return
    if case == "duplicate":
        source_path = tmp_path / "backlog.md"
        source_path.write_text(
            "## One\n<!-- id: same -->\n\n## Two\n<!-- id: same -->\n",
            encoding="utf-8",
        )
        source = MarkdownBacklog(source_path, relative_path="fixtures/backlog.md")
        before = source_path.read_bytes()
        with pytest.raises(expected, match="duplicate task id"):
            writeback_task(source, "same", BeadsClient(("unused-fake-bd",)))
        assert source_path.read_bytes() == before
        return
    source, state_path = seeded_source(
        tmp_path,
        status="open" if case == "state" else "closed",
        fingerprint="wrong" if case == "fingerprint" else None,
    )
    before = source.path.read_bytes()
    with pytest.raises(expected):
        writeback_task(source, "target-task", client_for(tmp_path, state_path))
    assert source.path.read_bytes() == before


def test_import_and_preview_paths_do_not_write(tmp_path: Path) -> None:
    source_path = tmp_path / "backlog.md"
    source_path.write_text("## Read only\nBody\n", encoding="utf-8")
    before = source_path.read_bytes()
    MarkdownBacklog(source_path).preview()
    MarkdownBacklog(source_path).materialize("read-only")
    assert source_path.read_bytes() == before


def test_writeback_cli_dispatches_explicit_command(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    source, state_path = seeded_source(tmp_path)
    client = client_for(tmp_path, state_path)
    from gascity_sidecar import cli

    monkeypatch.setattr(cli, "BeadsClient", lambda: client)
    assert cli.main(
        [
            "backlog",
            "writeback",
            "--source",
            str(source.path),
            "--relative-path",
            "fixtures/backlog.md",
            "target-task",
        ]
    ) == 0
    assert json.loads(capsys.readouterr().out)["action"] == "marked_done"


def test_import_path_remains_read_only(tmp_path: Path) -> None:
    source, state_path = seeded_source(tmp_path)
    before = source.path.read_bytes()
    import_task(source, "target-task", client_for(tmp_path, state_path))
    assert source.path.read_bytes() == before
