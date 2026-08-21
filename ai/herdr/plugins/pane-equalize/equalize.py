#!/usr/bin/env python3
import json
import os
import socket
import sys
from math import sqrt
from typing import Any


def request(method: str, params: dict[str, Any]) -> dict[str, Any]:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        raise RuntimeError("HERDR_SOCKET_PATH is not set")

    payload = json.dumps({"id": "pane-equalize", "method": method, "params": params})
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


def balanced_ratios(
    node: dict[str, Any], path: list[bool] | None = None
) -> tuple[int, int, int, list[tuple[list[bool], float]]]:
    path = path or []
    if node["type"] == "pane":
        return 1, 1, 1, []

    first_count, first_width, first_height, first_ratios = balanced_ratios(
        node["first"], path + [False]
    )
    second_count, second_width, second_height, second_ratios = balanced_ratios(
        node["second"], path + [True]
    )
    pane_count = first_count + second_count

    if node["direction"] == "right":
        first_span = first_width
        second_span = second_width
        width = first_width + second_width
        height = max(first_height, second_height)
    else:
        first_span = first_height
        second_span = second_height
        width = max(first_width, second_width)
        height = first_height + second_height

    # Blend equal-area counts with grid spans so cross-axis stacks do not
    # squeeze neighboring tall or wide panes.
    first_weight = sqrt(first_count * first_span)
    second_weight = sqrt(second_count * second_span)
    ratio = first_weight / (first_weight + second_weight)
    return (
        pane_count,
        width,
        height,
        [(path, ratio), *first_ratios, *second_ratios],
    )


def focused_pane_id() -> str:
    pane_id = os.environ.get("HERDR_PANE_ID")
    if pane_id:
        return pane_id
    context = json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))
    pane_id = context.get("focused_pane_id")
    if not pane_id:
        raise RuntimeError("no focused pane in plugin context")
    return pane_id


def equalize() -> str:
    pane_id = focused_pane_id()
    exported = request("layout.export", {"pane_id": pane_id})["layout"]
    pane_count, _, _, ratios = balanced_ratios(exported["root"])

    for path, ratio in ratios:
        request(
            "layout.set_split_ratio",
            {"tab_id": exported["tab_id"], "path": path, "ratio": ratio},
        )

    if pane_count == 1:
        return "tab already has one pane"
    return f"equalized {pane_count} panes"


def main() -> int:
    try:
        print(equalize())
        return 0
    except (KeyError, OSError, ValueError, RuntimeError) as error:
        print(f"pane-equalize: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
