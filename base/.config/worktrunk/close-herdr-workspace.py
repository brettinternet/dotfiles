#!/usr/bin/env python3
"""Close Herdr workspaces for a Worktrunk checkout after its removal."""

from __future__ import annotations

import json
import subprocess
import sys


def main(checkout_path: str) -> int:
    try:
        result = subprocess.run(
            ["herdr", "workspace", "list"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return 0

    if result.returncode:
        return 0

    try:
        workspaces = json.loads(result.stdout).get("result", {}).get("workspaces", [])
    except (AttributeError, json.JSONDecodeError):
        return 0

    workspace_ids = [
        workspace.get("workspace_id")
        for workspace in workspaces
        if workspace.get("worktree", {}).get("checkout_path") == checkout_path
    ]
    for workspace_id in filter(None, workspace_ids):
        subprocess.run(
            ["herdr", "workspace", "close", workspace_id],
            check=False,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
