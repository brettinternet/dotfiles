#!/usr/bin/env python3

import json
import os
import socket

SOURCE = "brett.pane-title"
SEPARATOR = " · "
OWNERSHIP_TOKEN = "brett_pane_title"


def herdr_request(method: str, params: dict) -> dict:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        raise RuntimeError("HERDR_SOCKET_PATH is not set")
    payload = json.dumps({"id": "pane-title", "method": method, "params": params})
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


def clean(value: object) -> str:
    return " ".join(str(value or "").split())


def pane_title(pane: dict, process_name: str = "") -> str:
    agent = clean(pane.get("display_agent") or pane.get("agent"))
    title = clean(pane.get("terminal_title_stripped"))
    detail = title or clean(process_name)
    if agent and detail and agent.casefold() != detail.casefold():
        return f"{agent}{SEPARATOR}{detail}"
    return agent or detail


def foreground_process_name(pane_id: str) -> str:
    result = herdr_request("pane.process_info", {"pane_id": pane_id})
    info = result.get("process_info", {})
    processes = info.get("foreground_processes", [])
    if not processes:
        return ""
    shell_pid = info.get("shell_pid")
    process = next((item for item in processes if item.get("pid") != shell_pid), processes[0])
    return clean(process.get("name") or process.get("argv0"))


def needs_process_name(pane: dict) -> bool:
    return (
        not clean(pane.get("label"))
        and not pane.get("agent")
        and not pane.get("display_agent")
        and not pane.get("terminal_title_stripped")
    )


def sync_pane(pane: dict, process_name: str | None = None) -> None:
    pane_id = pane["pane_id"]
    has_custom_label = bool(clean(pane.get("label")))
    needs_process = needs_process_name(pane)
    if needs_process and process_name is None:
        process_name = foreground_process_name(pane_id)
    desired = "" if has_custom_label else pane_title(pane, process_name or "")
    if desired and clean(pane.get("title")) != desired:
        herdr_request(
            "pane.report_metadata",
            {
                "pane_id": pane_id,
                "source": SOURCE,
                "title": desired,
                "tokens": {OWNERSHIP_TOKEN: "1"},
            },
        )
    elif not desired and pane.get("tokens", {}).get(OWNERSHIP_TOKEN):
        herdr_request(
            "pane.report_metadata",
            {
                "pane_id": pane_id,
                "source": SOURCE,
                "clear_title": True,
                "tokens": {OWNERSHIP_TOKEN: None},
            },
        )


def snapshot_panes() -> list[dict]:
    return herdr_request("session.snapshot", {})["snapshot"].get("panes", [])


def main() -> None:
    panes = snapshot_panes()
    target_pane_id = os.environ.get("HERDR_PANE_ID")
    if target_pane_id:
        panes = [pane for pane in panes if pane.get("pane_id") == target_pane_id]
    for pane in panes:
        sync_pane(pane)


if __name__ == "__main__":
    main()
