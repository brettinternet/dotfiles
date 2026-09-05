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


def expand_dotfiles(value: Any, dotfiles: Path) -> Any:
    if isinstance(value, str) and value.startswith("$DOTFILES/"):
        return str(dotfiles / value.removeprefix("$DOTFILES/"))
    if isinstance(value, list):
        return [expand_dotfiles(item, dotfiles) for item in value]
    if isinstance(value, Mapping):
        return {key: expand_dotfiles(item, dotfiles) for key, item in value.items()}
    return value


def main(argv: list[str]) -> int:
    if len(argv) != 7:
        print(
            "usage: merge-profile.py <common.json> <profile.json> "
            "<settings-output.json> <web-search-output.json> "
            "<title-output.jsonc> <dotfiles>",
            file=sys.stderr,
        )
        return 2

    common_path = Path(argv[1])
    profile_path = Path(argv[2])
    settings_output_path = Path(argv[3])
    web_search_output_path = Path(argv[4])
    title_output_path = Path(argv[5])
    dotfiles = Path(argv[6]).resolve()
    merged = expand_dotfiles(
        deep_merge(load_json(common_path), load_json(profile_path)), dotfiles
    )
    web_search_config = merged.pop("webSearchConfig", {})
    title_config = merged.pop("titleConfig", {})
    if not isinstance(web_search_config, dict):
        raise SystemExit(
            f"merge-profile: webSearchConfig in {profile_path} must be a JSON object"
        )
    if not isinstance(title_config, dict):
        raise SystemExit(
            f"merge-profile: titleConfig in {profile_path} must be a JSON object"
        )
    settings_output_path.write_text(
        json.dumps(merged, indent=2) + "\n", encoding="utf-8"
    )
    web_search_output_path.write_text(
        json.dumps(web_search_config, indent=2) + "\n", encoding="utf-8"
    )
    title_output_path.write_text(
        json.dumps(title_config, indent=2) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
