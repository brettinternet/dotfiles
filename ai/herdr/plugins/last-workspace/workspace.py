#!/usr/bin/env python3

import fcntl
import json
import os
import subprocess
import sys
from pathlib import Path


def focused_workspace() -> str:
    if workspace_id := os.environ.get("HERDR_WORKSPACE_ID"):
        return workspace_id

    if event := os.environ.get("HERDR_PLUGIN_EVENT_JSON"):
        data = json.loads(event)
        return data.get("data", {}).get("workspace_id") or data.get("workspace_id", "")

    result = subprocess.run(
        [os.environ.get("HERDR_BIN_PATH", "herdr"), "workspace", "list"],
        check=True,
        capture_output=True,
        text=True,
    )
    workspaces = json.loads(result.stdout)["result"]["workspaces"]
    return next((item["workspace_id"] for item in workspaces if item.get("focused")), "")


def record(state_dir: Path, workspace_id: str) -> str:
    if not workspace_id:
        return ""

    state_dir.mkdir(parents=True, exist_ok=True)
    current_path = state_dir / "current"
    previous_path = state_dir / "previous"
    current = current_path.read_text().strip() if current_path.exists() else ""
    if current == workspace_id:
        return previous_path.read_text().strip() if previous_path.exists() else ""

    if current:
        previous_path.write_text(f"{current}\n")
    current_path.write_text(f"{workspace_id}\n")
    return current


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"record", "toggle"}:
        raise SystemExit("usage: workspace.py record|toggle")

    state_dir = Path(os.environ["HERDR_PLUGIN_STATE_DIR"])
    state_dir.mkdir(parents=True, exist_ok=True)
    focused = focused_workspace()
    with (state_dir / ".lock").open("w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        previous = record(state_dir, focused)
    if sys.argv[1] == "toggle" and previous and previous != focused:
        subprocess.run(
            [os.environ.get("HERDR_BIN_PATH", "herdr"), "workspace", "focus", previous],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


if __name__ == "__main__":
    main()
