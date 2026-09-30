#!/usr/bin/env python3
"""Save Pi creation evidence in a linked worktree's own Git metadata."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    session_id = os.environ.get("PI_SESSION_ID")
    if not session_id:
        return 0  # Human-created worktrees must not become agent-owned.

    try:
        context = json.load(sys.stdin)
        if context["hook_type"] != "pre-start":
            raise ValueError("creation receipts require the pre-start hook")
        checkout = Path(context["worktree_path"]).resolve(strict=True)

        def git(*args: str) -> str:
            return subprocess.check_output(
                ["git", "-C", str(checkout), *args], text=True
            ).strip()

        git_dir = Path(git("rev-parse", "--absolute-git-dir"))
        common_dir = Path(
            git("rev-parse", "--path-format=absolute", "--git-common-dir")
        )
        if git_dir == common_dir or not (git_dir / "gitdir").is_file():
            raise ValueError("refusing to record a primary checkout")
        branch = git("branch", "--show-current") or None
        if branch != context.get("branch"):
            raise ValueError("hook branch does not match checkout")
        receipt = {
            "version": 1,
            "checkout_path": str(checkout),
            "branch": branch,
            "creation_commit": git("rev-parse", "HEAD"),
            "session_id": session_id,
            "session_file": os.environ.get("PI_SESSION_FILE"),
            "loop_id": os.environ.get("PI_LOOP_RUN_ID"),
        }
        # Exclusive creation: a rerun must never transfer or replace ownership.
        # Git removes this metadata with the checkout, avoiding stale receipts
        # when another worktree later reuses the same path or branch.
        receipt_path = git_dir / "agent-creation.json"
        with receipt_path.open("x") as output:
            json.dump(receipt, output, indent=2)
            output.write("\n")
        print(f"Agent worktree receipt: {receipt_path}")
    except (
        OSError,
        subprocess.CalledProcessError,
        ValueError,
        KeyError,
        TypeError,
    ) as error:
        print(f"Could not record agent worktree: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
