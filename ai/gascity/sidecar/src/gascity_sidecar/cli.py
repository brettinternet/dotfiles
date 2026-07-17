"""Command-line entry points for sidecar backlog operations."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from .backlog import MarkdownBacklog
from .backlog.base import BacklogError
from .backlog.beads import BeadsClient, import_task


def _source_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--source", type=Path, required=True, help="Markdown backlog path")
    parser.add_argument(
        "--relative-path",
        help="portable source path stored in external refs (defaults to source basename)",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="gascity-sidecar")
    groups = parser.add_subparsers(dest="group", required=True)
    backlog = groups.add_parser("backlog", help="inspect or materialize backlog tasks")
    commands = backlog.add_subparsers(dest="command", required=True)

    preview = commands.add_parser("preview", help="list Markdown tasks without Beads writes")
    _source_options(preview)

    materialize = commands.add_parser("import", help="materialize one Markdown task into Beads")
    _source_options(materialize)
    materialize.add_argument("task_id", help="one stable task ID to import")

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.group != "backlog":
            raise BacklogError("unsupported command")
        relative_path = args.relative_path or args.source.name
        source = MarkdownBacklog(args.source, relative_path=relative_path)
        if args.command == "preview":
            result = [
                {"id": task.id, "title": task.title, "actionable": task.actionable}
                for task in source.preview()
            ]
        else:
            result = import_task(source, args.task_id, BeadsClient()).as_dict()
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (BacklogError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
