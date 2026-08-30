#!/usr/bin/env python3
"""Materialize a Pi profile from a common base plus an overlay."""
from __future__ import annotations

import json
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"merge-profile: {path} must contain a JSON object")
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


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print("usage: merge-profile.py <common.json> <profile.json> <output.json>", file=sys.stderr)
        return 2

    common_path = Path(argv[1])
    profile_path = Path(argv[2])
    output_path = Path(argv[3])
    merged = deep_merge(load_json(common_path), load_json(profile_path))
    output_path.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
