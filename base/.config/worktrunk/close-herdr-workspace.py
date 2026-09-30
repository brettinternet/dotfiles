#!/usr/bin/env python3
"""Close Herdr workspaces for a Worktrunk checkout after its removal."""

from __future__ import annotations

import json
import os
import subprocess
import sys


def main(checkout_path: str) -> int:
    herdr = os.environ.get("HERDR_BIN_PATH", "herdr")

    def matching_workspaces() -> set[str]:
        result = subprocess.run(
            [herdr, "workspace", "list"],
            capture_output=True,
            text=True,
            check=True,
        )
        workspaces = json.loads(result.stdout)["result"]["workspaces"]
        return {
            workspace["workspace_id"]
            for workspace in workspaces
            if (workspace.get("worktree") or {}).get("checkout_path") == checkout_path
        }

    try:
        workspace_ids = matching_workspaces()
        for workspace_id in sorted(workspace_ids):
            subprocess.run(
                [herdr, "workspace", "close", workspace_id],
                check=True,
            )
        if workspace_ids and matching_workspaces():
            raise ValueError("matching workspace still exists after close")
    except (
        OSError,
        subprocess.CalledProcessError,
        ValueError,
        KeyError,
        TypeError,
        AttributeError,
    ) as error:
        print(f"Herdr cleanup failed for {checkout_path}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
