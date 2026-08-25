#!/usr/bin/env python3

import json
import os
import re
import shlex
import subprocess
import sys
import unicodedata
from pathlib import Path

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
MAGENTA = "\033[35m"
RED = "\033[31m"
GRAY = "\033[90m"
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

STATUS_STYLES = {
    "working": (YELLOW, "●"),
    "blocked": (RED + BOLD, "◆"),
    "done": (CYAN, "✓"),
    "idle": (GREEN, "○"),
    "unknown": (GRAY, "?"),
}


def styled(text: object, style: str) -> str:
    return f"{style}{clean(text)}{RESET}"


def status_label(status: object) -> str:
    value = clean(status) or "unknown"
    style, symbol = STATUS_STYLES.get(value, (MAGENTA, "•"))
    return f"{style}{symbol} {value}{RESET}"


def count_label(count: int, noun: str) -> str:
    return f"{count} {noun if count == 1 else noun + 's'}"

def preview_columns() -> int:
    try:
        return max(20, int(os.environ.get("FZF_PREVIEW_COLUMNS", "80")) - 1)
    except ValueError:
        return 79


def character_width(character: str) -> int:
    if unicodedata.combining(character):
        return 0
    if unicodedata.category(character).startswith("C"):
        return 0
    return 2 if unicodedata.east_asian_width(character) in {"W", "F"} else 1


def truncate_ansi_line(line: str, width: int) -> str:
    output = []
    display_width = 0
    index = 0
    while index < len(line):
        escape = ANSI_ESCAPE.match(line, index)
        if escape is not None:
            output.append(escape.group())
            index = escape.end()
            continue
        character = line[index]
        index += 1
        next_width = character_width(character)
        if display_width + next_width > width:
            break
        output.append(character)
        display_width += next_width
    return "".join(output).rstrip("\r") + RESET


def fit_ansi_screen(screen: str, width: int) -> list[str]:
    return [truncate_ansi_line(line, width) for line in screen.splitlines()]


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
                    styled(workspace.get("label") or workspace["workspace_id"], BOLD),
                    count_label(workspace.get("tab_count", 0), "tab"),
                    count_label(workspace.get("pane_count", 0), "pane"),
                    status_label(workspace.get("agent_status")),
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
        return styled("Workspace no longer exists", RED)
    columns = preview_columns()

    tab_count = workspace.get("tab_count", 0)
    pane_count = workspace.get("pane_count", 0)
    lines = [
        f"{styled(workspace.get('label') or workspace_id, BOLD + CYAN)}  "
        f"{status_label(workspace.get('agent_status'))}",
        styled(
            f"{count_label(tab_count, 'tab')} · {count_label(pane_count, 'pane')}",
            DIM,
        ),
        "",
    ]
    tabs = sorted(
        (item for item in state.get("tabs", []) if item["workspace_id"] == workspace_id),
        key=lambda item: item["number"],
    )
    panes = [item for item in state.get("panes", []) if item["workspace_id"] == workspace_id]
    for tab_index, tab in enumerate(tabs):
        tab_last = tab_index == len(tabs) - 1
        tab_branch = "└─" if tab_last else "├─"
        active = tab["tab_id"] == workspace.get("active_tab_id")
        tab_marker = styled("▶", CYAN) if active else styled("•", GRAY)
        tab_title = f"Tab {tab['number']}"
        lines.append(
            f"{styled(tab_branch, GRAY)} {tab_marker} "
            f"{styled(tab_title, BOLD if active else '')}  "
            f"{clean(tab.get('label') or tab['tab_id'])}  "
            f"{status_label(tab.get('agent_status'))}"
        )
        tab_panes = sorted(
            (item for item in panes if item["tab_id"] == tab["tab_id"]),
            key=lambda item: item["pane_id"],
        )
        trunk = "   " if tab_last else "│  "
        for pane_index, pane in enumerate(tab_panes):
            pane_branch = "└─" if pane_index == len(tab_panes) - 1 else "├─"
            agent = clean(pane.get("agent") or "shell")
            title = clean(pane.get("terminal_title_stripped")) or clean(pane.get("cwd"))
            lines.append(
                f"{styled(trunk + pane_branch, GRAY)} "
                f"{styled(pane['pane_id'], DIM)}  {styled(agent, MAGENTA)}  "
                f"{status_label(pane.get('agent_status'))}  {title}"
            )

    active_panes = [item for item in panes if item["tab_id"] == workspace.get("active_tab_id")]
    representative = next((item for item in active_panes if item.get("focused")), None)
    if representative is None and active_panes:
        representative = active_panes[0]
    if representative is not None:
        title = clean(representative.get("terminal_title_stripped"))
        lines.extend(
            [
                "",
                styled("─" * columns, GRAY),
                f"{styled('Pane preview', BOLD + CYAN)}  "
                f"{styled(representative['pane_id'], DIM)}  {title}",
                "",
            ]
        )
        try:
            screen = herdr_command(
                "pane",
                "read",
                representative["pane_id"],
                "--source",
                "visible",
                "--lines",
                "30",
                "--format",
                "ansi",
            ).stdout.rstrip()
        except subprocess.CalledProcessError:
            screen = styled("Pane preview unavailable", RED)
        lines.extend(fit_ansi_screen(screen, columns))

    return "\n".join(truncate_ansi_line(line, columns) for line in lines).rstrip()


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
            "--ansi",
            "--delimiter=\t",
            "--with-nth=2..",
            "--layout=reverse",
            "--info=inline-right",
            "--pointer=▸",
            "--prompt=Go to workspace › ",
            "--color=fg:-1,bg:-1,hl:cyan,fg+:white,bg+:-1,hl+:cyan,pointer:magenta,prompt:cyan,border:blue,label:blue,preview-border:blue,preview-label:blue,info:yellow",
            f"--preview={preview}",
            "--preview-label= Workspace preview ",
            "--preview-window=right,70%,nowrap,border-left",
            "--preview-wrap-sign=↳ ",
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
