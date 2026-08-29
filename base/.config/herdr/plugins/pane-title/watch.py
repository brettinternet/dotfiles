#!/usr/bin/env python3

import fcntl
import os
import time
from pathlib import Path

import sync

POLL_SECONDS = 2.0
FOCUSED_PROCESS_SECONDS = 2.0
BACKGROUND_PROCESS_SECONDS = 10.0
PLUGIN_CHECK_SECONDS = 10.0
MAX_SOCKET_FAILURES = 3


def plugin_enabled() -> bool:
    result = sync.herdr_request("plugin.list", {})
    return any(
        plugin.get("plugin_id") == sync.SOURCE and plugin.get("enabled")
        for plugin in result.get("plugins", [])
    )


def process_refresh_due(pane: dict, refreshed_at: dict[str, float], now: float) -> bool:
    interval = FOCUSED_PROCESS_SECONDS if pane.get("focused") else BACKGROUND_PROCESS_SECONDS
    return now - refreshed_at.get(pane["pane_id"], 0.0) >= interval


def refresh_panes(
    process_names: dict[str, str],
    process_refreshed_at: dict[str, float],
    now: float,
) -> tuple[dict[str, str], dict[str, float]]:
    panes = sync.snapshot_panes()
    live_pane_ids = {pane["pane_id"] for pane in panes}
    process_names = {
        pane_id: name
        for pane_id, name in process_names.items()
        if pane_id in live_pane_ids
    }
    process_refreshed_at = {
        pane_id: refreshed
        for pane_id, refreshed in process_refreshed_at.items()
        if pane_id in live_pane_ids
    }

    for pane in panes:
        pane_id = pane["pane_id"]
        needs_process = sync.needs_process_name(pane)
        if needs_process and process_refresh_due(pane, process_refreshed_at, now):
            process_names[pane_id] = sync.foreground_process_name(pane_id)
            process_refreshed_at[pane_id] = now
        elif not needs_process:
            process_names.pop(pane_id, None)
            process_refreshed_at.pop(pane_id, None)
        sync.sync_pane(pane, process_names.get(pane_id, ""))

    return process_names, process_refreshed_at


def run() -> None:
    state_dir = Path(os.environ["HERDR_PLUGIN_STATE_DIR"])
    state_dir.mkdir(parents=True, exist_ok=True)
    with (state_dir / "watch.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return

        process_names: dict[str, str] = {}
        process_refreshed_at: dict[str, float] = {}
        failures = 0
        next_plugin_check = time.monotonic() + PLUGIN_CHECK_SECONDS

        while True:
            started_at = time.monotonic()
            try:
                process_names, process_refreshed_at = refresh_panes(
                    process_names, process_refreshed_at, started_at
                )

                if started_at >= next_plugin_check:
                    if not plugin_enabled():
                        return
                    next_plugin_check = started_at + PLUGIN_CHECK_SECONDS
                failures = 0
            except (ConnectionError, OSError, RuntimeError):
                failures += 1
                if failures >= MAX_SOCKET_FAILURES:
                    return

            elapsed = time.monotonic() - started_at
            time.sleep(max(0.0, POLL_SECONDS - elapsed))


if __name__ == "__main__":
    run()
