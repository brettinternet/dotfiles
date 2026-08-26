#!/usr/bin/env python3

import argparse
import json
import math
import os
import select
import shutil
import socket
import sys
import termios
import time
import tty
import unicodedata
from dataclasses import dataclass

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
BLUE = "\033[34m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
MAGENTA = "\033[35m"
RED = "\033[31m"
GRAY = "\033[90m"
CLEAR_SCREEN = "\033[2J\033[H"
ENTER_ALT_SCREEN = "\033[?1049h\033[?25l"
LEAVE_ALT_SCREEN = "\033[?25h\033[?1049l"
MIN_CARD_WIDTH = 32
MIN_CARD_HEIGHT = 8
CARD_ASPECT = 2.2
REFRESH_SECONDS = 0.75

STATUS_STYLES = {
    "working": (YELLOW, "●"),
    "blocked": (RED, "◆"),
    "done": (CYAN, "✓"),
    "idle": (GREEN, "○"),
    "unknown": (GRAY, "?"),
}


@dataclass(frozen=True)
class Card:
    pane_id: str
    workspace_id: str
    workspace_number: int
    workspace_label: str
    tab_number: int
    tab_label: str
    agent: str
    status: str
    cwd: str
    title: str
    revision: int


@dataclass(frozen=True)
class Grid:
    columns: int
    rows: int
    card_width: int
    card_height: int
    capacity: int


def herdr_request(method: str, params: dict) -> dict:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        raise RuntimeError("HERDR_SOCKET_PATH is not set")
    payload = json.dumps({"id": "workspace-overview", "method": method, "params": params})
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


def character_width(character: str) -> int:
    if unicodedata.combining(character):
        return 0
    if unicodedata.category(character).startswith("C"):
        return 0
    return 2 if unicodedata.east_asian_width(character) in {"W", "F"} else 1


def display_width(text: str) -> int:
    return sum(character_width(character) for character in text)


def fit_text(value: object, width: int) -> str:
    text = str(value or "").replace("\t", " ").replace("\r", "")
    output = []
    used = 0
    for character in text:
        next_width = character_width(character)
        if used + next_width > width:
            break
        if not unicodedata.category(character).startswith("C"):
            output.append(character)
        used += next_width
    result = "".join(output)
    return result + " " * max(0, width - display_width(result))


def snapshot_cards(state: dict) -> list[Card]:
    workspaces = {item["workspace_id"]: item for item in state.get("workspaces", [])}
    tabs = {item["tab_id"]: item for item in state.get("tabs", [])}
    cards = []
    for pane in state.get("panes", []):
        workspace = workspaces.get(pane["workspace_id"], {})
        tab = tabs.get(pane["tab_id"], {})
        cards.append(
            Card(
                pane_id=pane["pane_id"],
                workspace_id=pane["workspace_id"],
                workspace_number=int(workspace.get("number", 0)),
                workspace_label=str(workspace.get("label") or pane["workspace_id"]),
                tab_number=int(tab.get("number", 0)),
                tab_label=str(tab.get("label") or ""),
                agent=str(pane.get("agent") or "shell"),
                status=str(pane.get("agent_status") or "unknown"),
                cwd=str(pane.get("cwd") or ""),
                title=str(pane.get("terminal_title_stripped") or ""),
                revision=int(pane.get("revision", 0)),
            )
        )
    return sorted(cards, key=lambda card: (card.workspace_number, card.tab_number, card.pane_id))


def calculate_grid(width: int, height: int, count: int) -> Grid:
    available_height = max(1, height - 3)
    max_columns = max(1, width // MIN_CARD_WIDTH)
    max_rows = max(1, available_height // MIN_CARD_HEIGHT)
    visible_count = min(max(1, count), max_columns * max_rows)
    candidates = []
    for columns in range(1, min(max_columns, visible_count) + 1):
        rows = math.ceil(visible_count / columns)
        if rows > max_rows:
            continue
        card_width = max(1, (width - columns + 1) // columns)
        card_height = max(1, (available_height - rows + 1) // rows)
        ratio = card_width / max(1, card_height)
        empty_slots = columns * rows - visible_count
        score = abs(math.log(max(ratio, 0.01) / CARD_ASPECT)) + empty_slots * 0.08
        candidates.append((score, -card_width * card_height, columns, rows, card_width, card_height))
    if not candidates:
        return Grid(1, 1, width, available_height, 1)
    _, _, columns, rows, card_width, card_height = min(candidates)
    return Grid(columns, rows, card_width, card_height, columns * rows)


def status_style(status: str) -> tuple[str, str]:
    return STATUS_STYLES.get(status, (MAGENTA, "•"))


def render_card(card: Card, preview: str, width: int, height: int, selected: bool) -> list[str]:
    inner_width = max(0, width - 2)
    border_style, symbol = status_style(card.status)
    top_left, horizontal, top_right = "┌", "─", "┐"
    vertical, bottom_left, bottom_right = "│", "└", "┘"
    if selected:
        border_style = BOLD + BLUE
        top_left, horizontal, top_right = "┏", "━", "┓"
        vertical, bottom_left, bottom_right = "┃", "┗", "┛"
    tab_name = f"Tab {card.tab_number}"
    if card.tab_label:
        tab_name += f" {card.tab_label}"
    title = fit_text(
        f" {card.workspace_number} {card.workspace_label} · {tab_name} · {card.pane_id} ",
        inner_width,
    ).rstrip()
    top_fill = max(0, inner_width - display_width(title))
    lines = [f"{border_style}{top_left}{title}{horizontal * top_fill}{top_right}{RESET}"]
    if height > 2:
        metadata = f"{symbol} {card.agent} · {card.status}"
        location = card.title or card.cwd
        if location:
            metadata += f" · {location}"
        lines.append(
            f"{border_style}{vertical}{RESET}{fit_text(metadata, inner_width)}"
            f"{border_style}{vertical}{RESET}"
        )
    content_height = max(0, height - 3)
    preview_lines = [line for line in preview.splitlines() if line.strip()]
    preview_lines = preview_lines[-content_height:]
    preview_lines = [""] * (content_height - len(preview_lines)) + preview_lines
    for line in preview_lines:
        lines.append(
            f"{border_style}{vertical}{RESET}{fit_text(line, inner_width)}"
            f"{border_style}{vertical}{RESET}"
        )
    if height > 1:
        lines.append(
            f"{border_style}{bottom_left}{horizontal * inner_width}{bottom_right}{RESET}"
        )
    return lines[:height]


def render_screen(
    cards: list[Card], previews: dict[str, str], selected: int, width: int, height: int
) -> tuple[str, Grid]:
    grid = calculate_grid(width, height, len(cards))
    page = selected // grid.capacity if cards else 0
    page_count = max(1, math.ceil(len(cards) / grid.capacity))
    page_cards = cards[page * grid.capacity : (page + 1) * grid.capacity]
    page_selected = selected - page * grid.capacity
    header = f"{BOLD}{CYAN}All workspaces{RESET}  {len(cards)} panes"
    if page_count > 1:
        header += f"  {DIM}page {page + 1}/{page_count}{RESET}"
    output = [header, ""]
    rows = math.ceil(len(page_cards) / grid.columns) if page_cards else 0
    card_height = max(1, (max(1, height - 3) - max(0, rows - 1)) // max(1, rows))
    for row in range(rows):
        row_cards = page_cards[row * grid.columns : (row + 1) * grid.columns]
        rendered = [
            render_card(
                card,
                previews.get(card.pane_id, "Pane preview unavailable"),
                grid.card_width,
                card_height,
                row * grid.columns + column == page_selected,
            )
            for column, card in enumerate(row_cards)
        ]
        for line_index in range(card_height):
            output.append(" ".join(card_lines[line_index] for card_lines in rendered))
        if row != rows - 1:
            output.append("")
    footer = "arrows/hjkl move · Enter focus · r refresh · q/Esc close"
    while len(output) < height - 1:
        output.append("")
    output.append(f"{DIM}{fit_text(footer, width)}{RESET}")
    return CLEAR_SCREEN + "\n".join(output[:height]), grid


class Overview:
    def __init__(self) -> None:
        self.cards: list[Card] = []
        self.previews: dict[str, str] = {}
        self.revisions: dict[str, int] = {}
        self.selected = 0
        self.force_refresh = True

    def refresh(self) -> None:
        selected_id = self.cards[self.selected].pane_id if self.cards else None
        state = herdr_request("session.snapshot", {})["snapshot"]
        self.cards = snapshot_cards(state)
        live_ids = {card.pane_id for card in self.cards}
        self.previews = {pane_id: text for pane_id, text in self.previews.items() if pane_id in live_ids}
        self.revisions = {pane_id: revision for pane_id, revision in self.revisions.items() if pane_id in live_ids}
        for card in self.cards:
            if self.force_refresh or self.revisions.get(card.pane_id) != card.revision:
                try:
                    result = herdr_request(
                        "pane.read",
                        {
                            "pane_id": card.pane_id,
                            "source": "visible",
                            "lines": 60,
                            "format": "text",
                            "strip_ansi": True,
                        },
                    )
                    self.previews[card.pane_id] = result["read"]["text"]
                except RuntimeError:
                    self.previews[card.pane_id] = "Pane preview unavailable"
                self.revisions[card.pane_id] = card.revision
        if selected_id:
            self.selected = next(
                (index for index, card in enumerate(self.cards) if card.pane_id == selected_id),
                min(self.selected, max(0, len(self.cards) - 1)),
            )
        else:
            self.selected = min(self.selected, max(0, len(self.cards) - 1))
        self.force_refresh = False

    def focus_selected(self) -> None:
        if not self.cards:
            return
        card = self.cards[self.selected]
        herdr_request("workspace.focus", {"workspace_id": card.workspace_id})
        herdr_request("pane.focus", {"pane_id": card.pane_id})

    def move(self, direction: str, columns: int) -> None:
        if not self.cards:
            return
        row_start = (self.selected // columns) * columns
        row_end = min(len(self.cards) - 1, row_start + columns - 1)
        if direction == "left":
            self.selected = max(row_start, self.selected - 1)
        elif direction == "right":
            self.selected = min(row_end, self.selected + 1)
        elif direction == "up":
            self.selected = max(0, self.selected - columns)
        elif direction == "down":
            self.selected = min(len(self.cards) - 1, self.selected + columns)


def terminal_size() -> tuple[int, int]:
    size = shutil.get_terminal_size((140, 60))
    return max(20, size.columns), max(8, size.lines)


def read_key(file_descriptor: int) -> bytes:
    key = os.read(file_descriptor, 1)
    if key != b"\x1b":
        return key
    while len(key) < 16:
        ready, _, _ = select.select([file_descriptor], [], [], 0.01)
        if not ready:
            break
        key += os.read(file_descriptor, 16 - len(key))
    return key


def run_once() -> None:
    overview = Overview()
    overview.refresh()
    width, height = terminal_size()
    screen, _ = render_screen(overview.cards, overview.previews, overview.selected, width, height)
    print(screen, end="")


def run_interactive() -> None:
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        raise RuntimeError("workspace overview requires an interactive terminal")
    overview = Overview()
    overview.refresh()
    file_descriptor = sys.stdin.fileno()
    previous_settings = termios.tcgetattr(file_descriptor)
    last_refresh = 0.0
    last_size = (0, 0)
    grid = Grid(1, 1, 1, 1, 1)
    try:
        tty.setcbreak(file_descriptor)
        sys.stdout.write(ENTER_ALT_SCREEN)
        sys.stdout.flush()
        running = True
        while running:
            now = time.monotonic()
            size = terminal_size()
            if overview.force_refresh or now - last_refresh >= REFRESH_SECONDS:
                overview.refresh()
                last_refresh = now
            if overview.force_refresh or size != last_size or now == last_refresh:
                screen, grid = render_screen(
                    overview.cards, overview.previews, overview.selected, size[0], size[1]
                )
                sys.stdout.write(screen)
                sys.stdout.flush()
                last_size = size
            ready, _, _ = select.select([file_descriptor], [], [], 0.1)
            if not ready:
                continue
            key = read_key(file_descriptor)
            if key in {b"q", b"\x1b", b"\x03"}:
                running = False
            elif key in {b"\r", b"\n"}:
                overview.focus_selected()
                running = False
            elif key in {b"h", b"\x1b[D"}:
                overview.move("left", grid.columns)
            elif key in {b"l", b"\x1b[C"}:
                overview.move("right", grid.columns)
            elif key in {b"k", b"\x1b[A"}:
                overview.move("up", grid.columns)
            elif key in {b"j", b"\x1b[B"}:
                overview.move("down", grid.columns)
            elif key == b"r":
                overview.force_refresh = True
            screen, grid = render_screen(
                overview.cards, overview.previews, overview.selected, size[0], size[1]
            )
            sys.stdout.write(screen)
            sys.stdout.flush()
    finally:
        termios.tcsetattr(file_descriptor, termios.TCSADRAIN, previous_settings)
        sys.stdout.write(LEAVE_ALT_SCREEN)
        sys.stdout.flush()


def main() -> None:
    parser = argparse.ArgumentParser(description="Responsive overview of Herdr workspace panes")
    parser.add_argument("--render-once", action="store_true", help="render one frame without entering raw mode")
    arguments = parser.parse_args()
    try:
        if arguments.render_once:
            run_once()
        else:
            run_interactive()
    except (OSError, RuntimeError, KeyError, ValueError) as error:
        raise SystemExit(f"workspace overview: {error}") from error


if __name__ == "__main__":
    main()
