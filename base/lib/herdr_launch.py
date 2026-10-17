"""Shared Herdr client and placement for the agent and pane launchers."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import subprocess
import sys

def herdr_client(args: argparse.Namespace):
    prefix = ["herdr"]
    if args.herdr_session is not None:
        prefix += ["--session", args.herdr_session]

    def h(*command: str) -> dict:
        # Never echo argv or Herdr diagnostics: they can contain --env secrets.
        result = subprocess.run([*prefix, *command], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(f"Herdr {' '.join(command[:2])} failed (exit {result.returncode}); inspect Herdr before retrying")
        # Unlike layout operations, pane run acknowledges submission with no stdout.
        if command[:2] == ("pane", "run") and not result.stdout.strip():
            return {"result": {"pane_id": command[2], "submitted": True}}
        response = json.loads(result.stdout)
        if response.get("error") or not isinstance(response.get("result"), dict):
            raise ValueError("Herdr returned an unsuccessful or malformed response")
        return response

    return h


@contextmanager
def placed_pane(h, args: argparse.Namespace, variables: dict[str, str], *,
                replacement: str | None = None, tool: str = "agent"):
    creation = ["--cwd", str(args.cwd), "--focus" if args.focus else "--no-focus"]
    for key, value in variables.items():
        creation += ["--env", f"{key}={value}"]
    pane = None
    replaced_pane = None
    try:
        if args.split:
            created = h("pane", "split", "--current", "--direction", args.split, *creation)
            pane = created["result"]["pane"]["pane_id"]
        else:
            workspace = os.environ.get("HERDR_WORKSPACE_ID")
            if args.workspace is not None:
                matches = []
                for candidate in h("workspace", "list")["result"]["workspaces"]:
                    if candidate["label"] != args.workspace:
                        continue
                    candidate_id = candidate["workspace_id"]
                    panes = h("pane", "list", "--workspace", candidate_id)["result"]["panes"]
                    if any(p.get("cwd") and Path(p["cwd"]).resolve() == args.cwd for p in panes):
                        matches.append(candidate_id)
                # Caller IDs are meaningful only within the inherited session.
                if args.herdr_session is None and workspace in matches:
                    matches = [workspace]
                if len(matches) > 1:
                    raise ValueError("Multiple workspaces match label and checkout; refusing to guess")
                workspace = matches[0] if matches else None
            tab = None
            if workspace and args.reuse_tab:
                tabs = [item for item in h("tab", "list", "--workspace", workspace)["result"]["tabs"]
                        if item["label"] == args.tab]
                tab = tabs[0]["tab_id"] if tabs else None
            panes = h("pane", "list", "--workspace", workspace)["result"]["panes"] if tab else []
            tab_panes = [item for item in panes if item["tab_id"] == tab]
            if replacement is not None and not any(item["pane_id"] == replacement for item in tab_panes):
                raise ValueError("Named agent is outside the selected tab; refusing to replace")
            if tab:
                if not tab_panes:
                    raise ValueError("Matching tab has no panes; refusing to guess")
                target = replacement if replacement is not None else tab_panes[0]["pane_id"]
                created = h("pane", "split", target, "--direction", "right", *creation)
                pane = created["result"]["pane"]["pane_id"]
                if replacement is not None:
                    replaced_pane = target
            elif workspace:
                created = h("tab", "create", "--workspace", workspace, "--label", args.tab, *creation)
                pane = created["result"]["root_pane"]["pane_id"]
            else:
                created = h("workspace", "create", "--label", args.workspace, *creation)
                pane = created["result"]["root_pane"]["pane_id"]
                h("tab", "rename", created["result"]["tab"]["tab_id"], args.tab)
        if args.pane_title is not None:
            # Herdr joins every remaining word into the label, including a literal "--".
            h("pane", "rename", pane, args.pane_title)
        if replaced_pane is not None:
            h("pane", "close", replaced_pane)
        yield pane
    except BaseException:  # including Ctrl-C during the startup wait
        if pane:
            print(f"{tool}: retained Herdr pane {pane}; inspect it before retrying (session {args.herdr_session or 'inherited'})", file=sys.stderr)
        raise
