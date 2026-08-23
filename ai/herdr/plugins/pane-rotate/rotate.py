#!/usr/bin/env python3
import fcntl
import json
import math
import os
import socket
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

DIRECTION_EXPECTATIONS = {
    "left": ("right", "second"),
    "right": ("right", "first"),
    "up": ("down", "second"),
    "down": ("down", "first"),
}
OPPOSITE_AXIS = {"right": "down", "down": "right"}


def request(method: str, params: dict[str, Any]) -> dict[str, Any]:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        raise RuntimeError("HERDR_SOCKET_PATH is not set")

    payload = json.dumps({"id": "pane-rotate", "method": method, "params": params})
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


def focused_pane_id() -> str:
    pane_id = os.environ.get("HERDR_PANE_ID")
    if pane_id:
        return pane_id
    context = json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))
    pane_id = context.get("focused_pane_id")
    if not pane_id:
        raise RuntimeError("no focused pane in plugin context")
    return pane_id


def requested_neighbor() -> str:
    action_id = os.environ.get("HERDR_PLUGIN_ACTION_ID", "")
    direction = action_id.rsplit(".", 1)[-1]
    if direction not in DIRECTION_EXPECTATIONS:
        raise RuntimeError("action must declare a left, right, up, or down neighbor")
    return direction


def find_parent_split(
    node: dict[str, Any], pane_id: str, path: list[bool] | None = None
) -> tuple[list[bool], str, dict[str, Any]] | None:
    path = path or []
    if node["type"] != "split":
        return None

    for branch, side in (("first", False), ("second", True)):
        child = node[branch]
        if child["type"] == "pane" and child["pane_id"] == pane_id:
            return path, branch, node
        found = find_parent_split(child, pane_id, path + [side])
        if found is not None:
            return found
    return None


def node_at(node: dict[str, Any], path: list[bool]) -> dict[str, Any]:
    current = node
    for side in path:
        if current.get("type") != "split":
            raise RuntimeError("pane layout changed during rotation")
        current = current["second" if side else "first"]
    return current


def is_pane(node: dict[str, Any], pane_id: str) -> bool:
    return node.get("type") == "pane" and node.get("pane_id") == pane_id


def split_matches(
    node: dict[str, Any], journal: dict[str, Any], direction: str
) -> bool:
    return (
        node.get("type") == "split"
        and node.get("direction") == direction
        and node.get("ratio") == journal["ratio"]
        and is_pane(node.get("first", {}), journal["first_pane_id"])
        and is_pane(node.get("second", {}), journal["second_pane_id"])
    )


def move_result(result: dict[str, Any]) -> dict[str, Any]:
    if result.get("type") != "pane_move" or not isinstance(
        result.get("move_result"), dict
    ):
        raise RuntimeError("Herdr returned an unexpected pane.move response")
    moved = result["move_result"]
    if not moved.get("changed"):
        reason = moved.get("reason") or "unknown reason"
        raise RuntimeError(f"Herdr did not move the pane: {reason}")
    return moved


def save_journal(path: Path, journal: dict[str, Any]) -> None:
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(journal, sort_keys=True) + "\n")
    temporary.replace(path)


@contextmanager
def state_lock(state_dir: Path) -> Iterator[Path]:
    state_dir.mkdir(parents=True, exist_ok=True)
    lock_path = state_dir / "rotation.lock"
    with lock_path.open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield state_dir / "rotation.json"


def export_layout(pane_id: str) -> dict[str, Any]:
    return request("layout.export", {"pane_id": pane_id})["layout"]


def recover_pending(journal_path: Path) -> str | None:
    try:
        journal = json.loads(journal_path.read_text())
    except FileNotFoundError:
        return None

    pane = request("pane.get", {"pane_id": journal["second_pane_id"]})["pane"]
    target_layout = export_layout(journal["first_pane_id"])
    if target_layout["tab_id"] != journal["tab_id"]:
        raise RuntimeError(
            "pending rotation target moved to another tab; refusing recovery"
        )
    target = node_at(target_layout["root"], journal["path"])

    if pane["tab_id"] == journal["tab_id"]:
        if split_matches(target, journal, journal["direction"]):
            journal_path.unlink()
            return "cleared interrupted rotation; layout was unchanged"
        if split_matches(target, journal, journal["new_direction"]):
            journal_path.unlink()
            return "completed rotation was already applied"
        raise RuntimeError("pane layout changed after rotation; refusing recovery")

    if not is_pane(target, journal["first_pane_id"]):
        raise RuntimeError(
            "pane layout changed while rotation was interrupted; refusing recovery"
        )

    move_result(
        request(
            "pane.move",
            {
                "pane_id": journal["second_pane_id"],
                "destination": {
                    "type": "tab",
                    "tab_id": journal["tab_id"],
                    "target_pane_id": journal["first_pane_id"],
                    "split": journal["direction"],
                    "ratio": journal["ratio"],
                },
                "focus": journal["focused_pane_id"] == journal["second_pane_id"],
            },
        )
    )
    journal_path.unlink()
    return "recovered interrupted rotation; invoke the action again to rotate"


def rotate() -> str:
    pane_id = focused_pane_id()
    direction = requested_neighbor()
    state_dir = Path(os.environ["HERDR_PLUGIN_STATE_DIR"])

    with state_lock(state_dir) as journal_path:
        recovered = recover_pending(journal_path)
        if recovered is not None:
            return recovered

        exported = export_layout(pane_id)
        if exported.get("zoomed"):
            raise RuntimeError("cannot rotate panes in a zoomed tab")
        parent = find_parent_split(exported["root"], pane_id)
        if parent is None:
            raise RuntimeError("the focused pane is not part of a split")

        path, side, split = parent
        expected_direction, expected_side = DIRECTION_EXPECTATIONS[direction]
        if split["direction"] != expected_direction or side != expected_side:
            raise RuntimeError(f"the focused pane has no direct {direction} sibling")
        if split["first"]["type"] != "pane" or split["second"]["type"] != "pane":
            raise RuntimeError(
                f"the focused pane's {direction} neighbor is not a direct pane sibling"
            )

        ratio = float(split["ratio"])
        if not math.isfinite(ratio) or not 0.0 < ratio < 1.0:
            raise RuntimeError("the containing split has an invalid ratio")

        first_pane_id = split["first"]["pane_id"]
        second_pane_id = split["second"]["pane_id"]
        new_direction = OPPOSITE_AXIS[split["direction"]]
        journal = {
            "tab_id": exported["tab_id"],
            "workspace_id": exported["workspace_id"],
            "focused_pane_id": pane_id,
            "first_pane_id": first_pane_id,
            "second_pane_id": second_pane_id,
            "path": path,
            "direction": split["direction"],
            "new_direction": new_direction,
            "ratio": ratio,
        }
        save_journal(journal_path, journal)

        try:
            move_result(
                request(
                    "pane.move",
                    {
                        "pane_id": second_pane_id,
                        "destination": {
                            "type": "new_tab",
                            "workspace_id": exported["workspace_id"],
                            "label": "pane rotation",
                        },
                        "focus": False,
                    },
                )
            )
            move_result(
                request(
                    "pane.move",
                    {
                        "pane_id": second_pane_id,
                        "destination": {
                            "type": "tab",
                            "tab_id": exported["tab_id"],
                            "target_pane_id": first_pane_id,
                            "split": new_direction,
                            "ratio": ratio,
                        },
                        "focus": pane_id == second_pane_id,
                    },
                )
            )
        except (KeyError, OSError, ValueError, RuntimeError) as error:
            try:
                recovered = recover_pending(journal_path)
            except (KeyError, OSError, ValueError, RuntimeError) as recovery_error:
                raise RuntimeError(
                    f"rotation failed ({error}); automatic recovery failed ({recovery_error})"
                ) from recovery_error
            raise RuntimeError(f"rotation failed ({error}); {recovered}") from error

        rotated = export_layout(first_pane_id)
        rotated_split = node_at(rotated["root"], path)
        if not split_matches(rotated_split, journal, new_direction):
            raise RuntimeError(
                "rotation completed but the resulting layout was unexpected"
            )
        journal_path.unlink()
        return f"rotated focused pane with its {direction} neighbor"


def main() -> int:
    try:
        print(rotate())
        return 0
    except (KeyError, OSError, ValueError, RuntimeError) as error:
        print(f"pane-rotate: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
