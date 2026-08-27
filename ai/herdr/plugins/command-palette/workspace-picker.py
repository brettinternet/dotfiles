#!/usr/bin/env python3

import json
import os
import re
import shlex
import socket
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


def herdr_request(method: str, params: dict) -> dict:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        raise RuntimeError("HERDR_SOCKET_PATH is not set")
    payload = json.dumps({"id": "workspace-picker", "method": method, "params": params})
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(socket_path)
        client.sendall(payload.encode() + b"\n")
        response = b""
        while b"\n" not in response:
            chunk = client.recv(65536)
            if not chunk:
                break
            response += chunk
    if not response:
        raise RuntimeError(f"Herdr returned no response for {method}")
    decoded = json.loads(response.splitlines()[0])
    if "error" in decoded:
        error = decoded["error"]
        raise RuntimeError(error.get("message") or error.get("code") or str(error))
    return decoded["result"]


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

def preview_index_path(workspace_id: str) -> Path | None:
    state_dir = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if not state_dir:
        return None
    safe_id = re.sub(r"[^A-Za-z0-9_-]", "_", workspace_id)
    directory = Path(state_dir)
    directory.mkdir(parents=True, exist_ok=True)
    return directory / f"workspace-preview-{safe_id}.index"



def selected_preview_index(workspace_id: str, pane_count: int, default: int) -> int:
    if pane_count == 0:
        return 0
    path = preview_index_path(workspace_id)
    if path is None:
        return default % pane_count
    try:
        selected = int(path.read_text().strip())
    except (FileNotFoundError, ValueError):
        selected = default
        path.write_text(f"{selected}\n")
    return selected % pane_count


def cycle_preview_pane(workspace_id: str, delta: int) -> None:
    path = preview_index_path(workspace_id)
    if path is None:
        return
    try:
        selected = int(path.read_text().strip())
    except (FileNotFoundError, ValueError):
        selected = 0
    path.write_text(f"{selected + delta}\n")


def reset_preview_indexes() -> None:
    state_dir = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if not state_dir:
        return
    for path in Path(state_dir).glob("workspace-preview-*.index"):
        path.unlink(missing_ok=True)


def ordered_workspace_panes(state: dict, workspace_id: str) -> list[dict]:
    tabs = sorted(
        (item for item in state.get("tabs", []) if item["workspace_id"] == workspace_id),
        key=lambda item: item["number"],
    )
    panes = [item for item in state.get("panes", []) if item["workspace_id"] == workspace_id]
    return [
        pane
        for tab in tabs
        for pane in sorted(
            (item for item in panes if item["tab_id"] == tab["tab_id"]),
            key=lambda item: item["pane_id"],
        )
    ]

def default_workspace_pane_index(
    state: dict, workspace_id: str, panes: list[dict]
) -> int:
    workspace = next(
        (item for item in state.get("workspaces", []) if item["workspace_id"] == workspace_id),
        {},
    )
    active_tab_id = workspace.get("active_tab_id")
    return next(
        (
            index
            for index, pane in enumerate(panes)
            if pane.get("focused") and pane["tab_id"] == active_tab_id
        ),
        next(
            (
                index
                for index, pane in enumerate(panes)
                if pane["tab_id"] == active_tab_id
            ),
            0,
        ),
    )


def focus_selection(state: dict, target_id: str, workspace_id: str) -> None:
    herdr_command("workspace", "focus", workspace_id)
    panes = ordered_workspace_panes(state, workspace_id)
    if not panes:
        return
    target = next((pane for pane in panes if pane["pane_id"] == target_id), None)
    if target is None:
        default_pane = next((index for index, pane in enumerate(panes) if pane.get("focused")), 0)
        target = panes[selected_preview_index(workspace_id, len(panes), default_pane)]
    herdr_request("pane.focus", {"pane_id": target["pane_id"]})

def workspace_rows(state: dict) -> str:
    rows = []
    for workspace in sorted(state.get("workspaces", []), key=lambda item: item["number"]):
        workspace_id = workspace["workspace_id"]
        rows.append(
            "\t".join(
                [
                    workspace_id,
                    workspace_id,
                    styled(workspace.get("label") or workspace_id, BOLD),
                    count_label(workspace.get("tab_count", 0), "tab"),
                    count_label(workspace.get("pane_count", 0), "pane"),
                    status_label(workspace.get("agent_status")),
                ]
            )
        )
    return "\n".join(rows)


def pane_rows(state: dict, workspace_id: str, after_pane_id: str | None = None) -> str:
    tabs = {tab["tab_id"]: tab for tab in state.get("tabs", [])}
    panes = ordered_workspace_panes(state, workspace_id)
    current = next((pane for pane in panes if pane["pane_id"] == after_pane_id), None)
    if current is not None:
        tab_ids = list(dict.fromkeys(pane["tab_id"] for pane in panes))
        current_tab = tab_ids.index(current["tab_id"])
        next_tab_id = tab_ids[(current_tab + 1) % len(tab_ids)]
        next_tab = next(
            index for index, pane in enumerate(panes) if pane["tab_id"] == next_tab_id
        )
        panes = panes[next_tab:] + panes[:next_tab]
    elif panes:
        current_pane = selected_preview_index(
            workspace_id,
            len(panes),
            default_workspace_pane_index(state, workspace_id, panes),
        )
        panes = panes[current_pane:] + panes[:current_pane]

    rows = []
    for pane in panes:
        tab = tabs.get(pane["tab_id"], {})
        rows.append(
            "\t".join(
                [
                    pane["pane_id"],
                    workspace_id,
                    styled(f"Tab {tab.get('number', '?')}", CYAN),
                    styled(pane["pane_id"], BOLD),
                    styled(clean(pane.get("agent") or "shell"), MAGENTA),
                    status_label(pane.get("agent_status")),
                    clean(pane.get("terminal_title_stripped")) or clean(pane.get("cwd")),
                ]
            )
        )
    return "\n".join(rows)


def workspace_preview(state: dict, workspace_id: str, target_id: str | None = None) -> str:
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
    ordered_panes = ordered_workspace_panes(state, workspace_id)
    default_pane = default_workspace_pane_index(state, workspace_id, ordered_panes)
    pane_index = next(
        (index for index, pane in enumerate(ordered_panes) if pane["pane_id"] == target_id),
        selected_preview_index(workspace_id, len(ordered_panes), default_pane),
    )
    representative = ordered_panes[pane_index] if ordered_panes else None
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
        for tab_pane_index, pane in enumerate(tab_panes):
            pane_branch = "└─" if tab_pane_index == len(tab_panes) - 1 else "├─"
            agent = clean(pane.get("agent") or "shell")
            title = clean(pane.get("terminal_title_stripped")) or clean(pane.get("cwd"))
            selected = representative is not None and pane["pane_id"] == representative["pane_id"]
            pane_marker = styled("▶", CYAN) if selected else " "
            lines.append(
                f"{styled(trunk + pane_branch, GRAY)} {pane_marker}"
                f"{styled(pane['pane_id'], BOLD if selected else DIM)}  "
                f"{styled(agent, MAGENTA)}  {status_label(pane.get('agent_status'))}  "
                f"{styled(title, BOLD) if selected else title}"
            )

    if representative is not None:
        title = clean(representative.get("terminal_title_stripped"))
        lines.extend(
            [
                "",
                styled("─" * columns, GRAY),
                f"{styled(f'Pane {pane_index + 1}/{len(ordered_panes)}', BOLD + CYAN)}  "
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
    reset_preview_indexes()
    state = snapshot()
    rows = workspace_rows(state)
    if not rows:
        return

    script = Path(__file__).resolve()
    command = f"{shlex.quote(sys.executable)} {shlex.quote(str(script))}"
    preview = f"{command} preview {{1}} {{2}}"
    pane_rows_command = f"{command} rows-panes {{2}} {{1}}"
    workspace_rows_command = f"{command} rows-workspaces"
    cycle_up = f"{command} cycle {{2}} -1"
    cycle_down = f"{command} cycle {{2}} 1"
    pane_prompt = "Search panes › "
    workspace_prompt = "Go to workspace › "
    pane_label = " Pane search · Ctrl-B/H back "
    workspace_label = " Workspace preview · Ctrl-F/L search panes "
    pane_mode = f"reload-sync({pane_rows_command})+first+change-prompt({pane_prompt})+enable-search+clear-query+change-preview-label({pane_label})"
    workspace_mode = f"reload-sync({workspace_rows_command})+change-prompt({workspace_prompt})+enable-search+clear-query+change-preview-label({workspace_label})"
    bindings = [
        "ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up",
        f"ctrl-f:{pane_mode},ctrl-l:{pane_mode}",
        f"ctrl-b:{workspace_mode},ctrl-h:{workspace_mode}",
        f"alt-up:execute-silent({cycle_up})+refresh-preview",
        f"alt-down:execute-silent({cycle_down})+refresh-preview",
    ]
    selected = subprocess.run(
        [
            "fzf",
            "--ansi",
            *[f"--bind={binding}" for binding in bindings],
            "--delimiter=\t",
            "--with-nth=3..",
            "--id-nth=2",
            "--track",
            "--layout=reverse",
            "--cycle",
            "--info=inline-right",
            "--pointer=▶",
            "--no-scrollbar",
            f"--prompt={workspace_prompt}",
            "--color=fg:-1,bg:-1,hl:cyan,fg+:white,bg+:-1,hl+:cyan,pointer:magenta,prompt:cyan,border:blue,label:blue,preview-border:blue,preview-label:blue,info:yellow",
            f"--preview={preview}",
            f"--preview-label={workspace_label}",
            "--preview-window=right,70%,nowrap,border-left",
        ],
        input=f"{rows}\n",
        capture_output=True,
        text=True,
        check=False,
    )
    if selected.returncode != 0 or not selected.stdout.strip():
        return

    target_id, workspace_id = selected.stdout.split("\t", 2)[:2]
    focus_selection(state, target_id, workspace_id)


def main() -> None:
    if len(sys.argv) == 4 and sys.argv[1] == "preview":
        print(workspace_preview(snapshot(), sys.argv[3], sys.argv[2]))
        return
    if len(sys.argv) == 4 and sys.argv[1] == "rows-panes":
        print(pane_rows(snapshot(), sys.argv[2], sys.argv[3]))
        return
    if len(sys.argv) == 2 and sys.argv[1] == "rows-workspaces":
        print(workspace_rows(snapshot()))
        return
    if len(sys.argv) == 4 and sys.argv[1] == "cycle":
        cycle_preview_pane(sys.argv[2], int(sys.argv[3]))
        return
    if len(sys.argv) != 1:
        raise SystemExit(
            "usage: workspace-picker.py [preview TARGET_ID WORKSPACE_ID | rows-panes WORKSPACE_ID AFTER_PANE_ID | rows-workspaces | cycle WORKSPACE_ID DELTA]"
        )
    pick_workspace()


if __name__ == "__main__":
    main()
