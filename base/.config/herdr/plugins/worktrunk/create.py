#!/usr/bin/env python3
"""Create a project-local worktree through Worktrunk from a Herdr popup."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def source_checkout(environment: dict[str, str]) -> str | None:
    try:
        context = json.loads(environment.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))
    except json.JSONDecodeError:
        return None

    worktree = context.get("worktree") or {}
    return worktree.get("checkout_path") or context.get("workspace_cwd")


def main() -> int:
    checkout = source_checkout(dict(os.environ))
    if not checkout:
        print("The selected Herdr workspace is not backed by a Git checkout.")
        input("Press Enter to close…")
        return 1

    print(f"Project: {Path(checkout).name}")
    branch = input("New branch: ").strip()
    if not branch:
        return 0

    base = input("Base [current branch]: ").strip() or "@"
    environment = dict(os.environ)
    environment["WORKTRUNK_HERDR_FOCUS"] = "1"

    try:
        result = subprocess.run(
            [
                "wt",
                "-C",
                checkout,
                "switch",
                "--create",
                branch,
                "--base",
                base,
                "--no-cd",
                "--format=json",
            ],
            env=environment,
            check=False,
        )
    except FileNotFoundError:
        print("Worktrunk is not installed or is not on PATH.", file=sys.stderr)
        result_code = 127
    else:
        result_code = result.returncode

    if result_code:
        input("Creation failed. Press Enter to close…")
    return result_code


if __name__ == "__main__":
    raise SystemExit(main())
