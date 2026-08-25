#!/usr/bin/env python3

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path


def herdr_command(*arguments: str, text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [os.environ.get("HERDR_BIN_PATH", "herdr"), *arguments],
        check=True,
        capture_output=True,
        text=True,
        input=text,
    )


def snapshot() -> dict:
    result = herdr_command("api", "snapshot")
    return json.loads(result.stdout)["result"]["snapshot"]


def clean(value: object) -> str:
    return str(value or "").replace("\t", " ").replace("\n", " ")


def workspace_rows(state: dict) -> str:
    rows = []
    for workspace in sorted(state.get("workspaces", []), key=lambda item: item["number"]):
        rows.append(
            "\t".join(
                [
                    workspace["workspace_id"],
                    clean(workspace.get("label") or workspace["workspace_id"]),
                    f"{workspace.get('tab_count', 0)} tabs",
                    f"{workspace.get('pane_count', 0)} panes",
                    clean(workspace.get("agent_status")),
                ]
            )
        )
    return "\n".join(rows)


def workspace_preview(state: dict, workspace_id: str) -> str:
    workspace = next(
        (item for item in state.get("workspaces", []) if item["workspace_id"] == workspace_id),
        None,
    )
    if workspace is None:
        return "Workspace no longer exists"

    lines = [
        f"{workspace.get('label') or workspace_id}  [{workspace.get('agent_status', '')}]",
        "",
    ]
    tabs = sorted(
        (item for item in state.get("tabs", []) if item["workspace_id"] == workspace_id),
        key=lambda item: item["number"],
    )
    panes = [item for item in state.get("panes", []) if item["workspace_id"] == workspace_id]
    for tab in tabs:
        marker = "*" if tab["tab_id"] == workspace.get("active_tab_id") else " "
        lines.append(
            f"{marker} Tab {tab['number']}: {tab.get('label') or tab['tab_id']}"
            f"  [{tab.get('agent_status', '')}]"
        )
        for pane in sorted(
            (item for item in panes if item["tab_id"] == tab["tab_id"]),
            key=lambda item: item["pane_id"],
        ):
            agent = clean(pane.get("agent") or "shell")
            status = clean(pane.get("agent_status"))
            title = clean(pane.get("terminal_title_stripped"))
            lines.append(f"    {pane['pane_id']}  {agent} {status}  {title}")
        lines.append("")

    active_panes = [item for item in panes if item["tab_id"] == workspace.get("active_tab_id")]
    representative = next((item for item in active_panes if item.get("focused")), None)
    if representative is None and active_panes:
        representative = active_panes[0]
    if representative is not None:
        lines.extend(["─" * 60, clean(representative.get("terminal_title_stripped")), ""])
        try:
            screen = herdr_command(
                "pane",
                "read",
                representative["pane_id"],
                "--source",
                "visible",
                "--lines",
                "30",
            ).stdout.rstrip()
        except subprocess.CalledProcessError:
            screen = "Pane preview unavailable"
        lines.append(screen)

    return "\n".join(lines).rstrip()


def pick_workspace() -> None:
    state = snapshot()
    rows = workspace_rows(state)
    if not rows:
        return

    script = Path(__file__).resolve()
    preview = f"{shlex.quote(sys.executable)} {shlex.quote(str(script))} preview {{1}}"
    selected = subprocess.run(
        [
            "fzf",
            "--delimiter=\t",
            "--with-nth=2..",
            "--prompt=Go to workspace> ",
            f"--preview={preview}",
            "--preview-window=right,65%,wrap",
        ],
        input=f"{rows}\n",
        capture_output=True,
        text=True,
        check=False,
    )
    if selected.returncode != 0 or not selected.stdout.strip():
        return

    workspace_id = selected.stdout.split("\t", 1)[0]
    herdr_command("workspace", "focus", workspace_id)


def main() -> None:
    if len(sys.argv) == 3 and sys.argv[1] == "preview":
        print(workspace_preview(snapshot(), sys.argv[2]))
        return
    if len(sys.argv) != 1:
        raise SystemExit("usage: workspace-picker.py [preview WORKSPACE_ID]")
    pick_workspace()


if __name__ == "__main__":
    main()
