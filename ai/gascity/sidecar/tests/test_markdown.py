from __future__ import annotations

from hashlib import sha256
from pathlib import Path

import pytest

from gascity_sidecar.backlog import (
    DuplicateTaskIdError,
    MalformedBacklogError,
    MarkdownBacklog,
    MissingDependencyError,
    ReadOnlySourceError,
    TaskState,
    fingerprint_section,
    normalize_section_body,
    parse_markdown,
)


ROOT = Path(__file__).parents[2]
FIXTURE = ROOT / "fixtures" / "backlog.md"
EDGE = Path(__file__).parent / "fixtures"


def test_fixture_ids_refs_and_actionability() -> None:
    tasks = MarkdownBacklog(FIXTURE, relative_path="fixtures/backlog.md").preview()

    assert [task.id for task in tasks] == ["fix-dep", "fix-review", "fix-independent"]
    assert tasks[0].external_ref == "md:fixtures/backlog.md#fix-dep"
    assert tasks[1].dependencies == ("FIX-DEP",)
    assert [task.actionable for task in tasks] == [True, False, True]
    assert all(not task.done for task in tasks)


def test_explicit_id_wins_and_materialize_is_read_only() -> None:
    source = MarkdownBacklog.from_text(
        "## A Human Title\n<!-- id: ENG-42 -->\nStatus: done\n",
        source_path="notes/work.md",
    )
    before = source._text

    task = source.materialize("ENG-42")
    assert task.id == "ENG-42"
    assert task.external_ref == "md:notes/work.md#ENG-42"
    assert task.done is True
    assert task.actionable is False
    assert source.preview()[0] == task
    assert source._text == before
    with pytest.raises(ReadOnlySourceError):
        source.writeback("ENG-42", TaskState(done=False))
    assert source._text == before


def test_fingerprint_normalizes_line_endings_trailing_space_and_outer_blanks() -> None:
    body = "\r\n  content  \r\n\r\nnext\t\r\n"
    normalized = "  content\n\nnext"
    assert normalize_section_body(body) == normalized
    assert fingerprint_section(body) == sha256(normalized.encode()).hexdigest()


def test_done_status_values_and_non_done_status() -> None:
    text = """## Completed
Status: COMPLETED

## Active
Status: in progress

- [x] Acceptance criterion (does not mark this task done)
"""
    completed, active = parse_markdown(text)
    assert completed.done is True
    assert completed.actionable is False
    assert active.done is False
    assert active.actionable is True


@pytest.mark.parametrize("fixture", ["duplicate-id.md", "slug-collision.md"])
def test_identity_collisions_refuse_import(fixture: str) -> None:
    with pytest.raises(DuplicateTaskIdError):
        MarkdownBacklog(EDGE / fixture).preview()


def test_missing_dependencies_are_typed_errors() -> None:
    with pytest.raises(MissingDependencyError) as raised:
        MarkdownBacklog(EDGE / "missing-dependency.md").preview()
    assert raised.value.task_id == "needs-a-task"
    assert raised.value.dependency_id == "absent-task"


def test_malformed_sections_are_typed_errors() -> None:
    with pytest.raises(MalformedBacklogError):
        MarkdownBacklog(EDGE / "malformed.md").preview()
    with pytest.raises(MalformedBacklogError):
        parse_markdown("## Valid\nDepends on: nope id\n")
    with pytest.raises(MalformedBacklogError):
        parse_markdown("## Valid\n<!-- id: -->\n")
    with pytest.raises(MalformedBacklogError):
        parse_markdown(None)  # type: ignore[arg-type]


def test_preview_and_materialize_never_write_source(tmp_path: Path) -> None:
    source_file = tmp_path / "backlog.md"
    source_file.write_text("## Read me\nBody\n", encoding="utf-8")
    before = source_file.read_bytes()
    adapter = MarkdownBacklog(source_file)

    adapter.preview()
    adapter.materialize("read-me")

    assert source_file.read_bytes() == before
