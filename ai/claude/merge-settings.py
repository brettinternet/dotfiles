#!/usr/bin/env python3
"""Merge managed Claude preferences into mutable user settings."""
from __future__ import annotations

import json
import os
import sys
import tempfile
from collections.abc import Mapping
from pathlib import Path
from typing import Any


def load_json_object(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"Claude settings must contain a JSON object: {path}")
    return data


def deep_merge(base: Mapping[str, Any], overlay: Mapping[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in overlay.items():
        base_value = merged.get(key)
        if isinstance(base_value, Mapping) and isinstance(value, Mapping):
            merged[key] = deep_merge(base_value, value)
        else:
            merged[key] = value
    return merged


def write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=path.parent, delete=False
    ) as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
        temporary = Path(handle.name)
    if path.exists():
        os.chmod(temporary, path.stat().st_mode)
    temporary.replace(path)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: merge-settings.py <preferred.json> <user.json>", file=sys.stderr)
        return 2

    preferred_path = Path(argv[1])
    user_path = Path(argv[2])
    if user_path.is_symlink():
        raise SystemExit(f"Refusing to modify linked Claude settings: {user_path}")
    if user_path.exists() and not user_path.is_file():
        raise SystemExit(f"Claude settings target is not a regular file: {user_path}")

    preferred = load_json_object(preferred_path)
    current = load_json_object(user_path) if user_path.exists() else {}
    write_json_atomic(user_path, deep_merge(current, preferred))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
