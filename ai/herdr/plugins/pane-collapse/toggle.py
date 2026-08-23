#!/usr/bin/env python3
import json
import os
import socket
import sys
from pathlib import Path
from typing import Any

COLLAPSED_FIRST_RATIO = 0.1
COLLAPSED_SECOND_RATIO = 0.9


def request(method: str, params: dict[str, Any]) -> dict[str, Any]:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        raise RuntimeError("HERDR_SOCKET_PATH is not set")

    payload = json.dumps({"id": "pane-collapse", "method": method, "params": params})
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


def pane_ids(node: dict[str, Any]) -> list[str]:
    if node["type"] == "pane":
        return [node["pane_id"]]
    return pane_ids(node["first"]) + pane_ids(node["second"])


def split_signature(node: dict[str, Any]) -> dict[str, Any]:
    """Describe split structure and membership without ratios or orientation."""
    if node["type"] == "pane":
        return {"type": "pane", "pane_id": node["pane_id"]}
    return {
        "type": "split",
        "first": split_signature(node["first"]),
        "second": split_signature(node["second"]),
    }


def find_parent_split(
    node: dict[str, Any], pane_id: str, path: list[bool] | None = None
) -> tuple[list[bool], str, dict[str, Any]] | None:
    path = path or []
    if node["type"] != "split":
        return None

    if pane_id in pane_ids(node["first"]):
        if node["first"]["type"] == "pane" and node["first"]["pane_id"] == pane_id:
            return path, "first", node
        return find_parent_split(node["first"], pane_id, path + [False])

    if pane_id in pane_ids(node["second"]):
        if node["second"]["type"] == "pane" and node["second"]["pane_id"] == pane_id:
            return path, "second", node
        return find_parent_split(node["second"], pane_id, path + [True])

    return None


def load_state(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return {}


def save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(state, sort_keys=True) + "\n")
    temporary.replace(path)


def focused_pane_id() -> str:
    pane_id = os.environ.get("HERDR_PANE_ID")
    if pane_id:
        return pane_id
    context = json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))
    pane_id = context.get("focused_pane_id")
    if not pane_id:
        raise RuntimeError("no focused pane in plugin context")
    return pane_id


def toggle() -> str:
    pane_id = focused_pane_id()
    exported = request("layout.export", {"pane_id": pane_id})["layout"]
    parent = find_parent_split(exported["root"], pane_id)
    if parent is None:
        raise RuntimeError("the focused pane is not part of a split")

    path, side, split = parent
    state_path = Path(os.environ["HERDR_PLUGIN_STATE_DIR"]) / "collapsed-panes.json"
    state = load_state(state_path)
    saved = state.get(pane_id)

    if saved is not None:
        topology_matches = (
            saved["tab_id"] == exported["tab_id"]
            and saved["path"] == path
            and saved["side"] == side
            and split_signature(saved["signature"]) == split_signature(split)
        )
        if not topology_matches:
            raise RuntimeError(
                "pane layout changed since collapse; refusing unsafe restore"
            )
        request(
            "layout.set_split_ratio",
            {"tab_id": exported["tab_id"], "path": path, "ratio": saved["ratio"]},
        )
        del state[pane_id]
        save_state(state_path, state)
        return f"restored {pane_id}"

    ratio = COLLAPSED_FIRST_RATIO if side == "first" else COLLAPSED_SECOND_RATIO
    request(
        "layout.set_split_ratio",
        {"tab_id": exported["tab_id"], "path": path, "ratio": ratio},
    )
    state[pane_id] = {
        "tab_id": exported["tab_id"],
        "path": path,
        "side": side,
        "ratio": split["ratio"],
        "signature": split_signature(split),
    }
    save_state(state_path, state)
    return f"collapsed {pane_id}"


def main() -> int:
    try:
        print(toggle())
        return 0
    except (KeyError, OSError, ValueError, RuntimeError) as error:
        print(f"pane-collapse: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
