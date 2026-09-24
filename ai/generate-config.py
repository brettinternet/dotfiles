#!/usr/bin/env python3
"""Render model catalogs and harness profiles from ai/manifest.yaml."""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import Any

AI_ROOT = Path(__file__).resolve().parent
ROOT = AI_ROOT.parent
sys.path.insert(0, str(ROOT / "dotbot/lib/pyyaml/lib"))

import yaml  # type: ignore[import-untyped]  # noqa: E402

EFFORTS = {"off", "minimal", "low", "medium", "high", "xhigh", "max"}
# Standalone CLI agents reuse the Pi profile that targets the same provider.
CLI_AGENT_PROFILES = {"claude": ("claude", "anthropic"), "codex": ("codex", "openai-codex")}
CLI_EFFORTS = {"low", "medium", "high", "xhigh", "max"}


class ManifestLoader(yaml.SafeLoader):
    """Load YAML 1.2 booleans without treating `off` as false."""


ManifestLoader.yaml_implicit_resolvers = {
    key: [resolver for resolver in resolvers if resolver[0] != "tag:yaml.org,2002:bool"]
    for key, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}
ManifestLoader.add_implicit_resolver(
    "tag:yaml.org,2002:bool",
    re.compile(r"^(?:true|True|TRUE|false|False|FALSE)$"),
    list("tTfF"),
)

def deep_merge(base: Mapping[str, Any], overlay: Mapping[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in overlay.items():
        if isinstance(merged.get(key), Mapping) and isinstance(value, Mapping):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


class Manifest:
    def __init__(self, path: Path) -> None:
        data = yaml.load(path.read_text(), Loader=ManifestLoader)
        if not isinstance(data, dict) or data.get("version") != 1:
            raise SystemExit(f"{path}: expected manifest version 1")
        self.path = path
        self.pi_launchers: dict[str, Any] = data.get("piLaunchers", {})
        self.agent_prompts = {
            source.stem: source.read_text() for source in sorted((AI_ROOT / "agents").glob("*.md"))
        }
        self.models: dict[str, Any] = data.get("models", {})
        self.profiles: dict[str, Any] = data.get("profiles", {})
        self.validate()

    def validate(self) -> None:
        for name, launcher in self.pi_launchers.items():
            location = f"piLaunchers.{name}"
            if not re.fullmatch(r"[a-z][a-z0-9-]*", name) or name == "list":
                raise SystemExit(f"{self.path}: invalid Pi launcher name {name!r}")
            if not isinstance(launcher, dict) or not launcher:
                raise SystemExit(f"{self.path}: {location} must be a non-empty mapping")
            unknown = set(launcher) - {"model", "thinking", "args"}
            if unknown:
                raise SystemExit(
                    f"{self.path}: unknown keys at {location}: {', '.join(sorted(unknown))}"
                )
            if "model" in launcher:
                if not isinstance(launcher["model"], str):
                    raise SystemExit(f"{self.path}: {location}.model must be a model alias")
                self.model_id(launcher["model"])
            if "thinking" in launcher:
                if not isinstance(launcher["thinking"], str):
                    raise SystemExit(f"{self.path}: {location}.thinking must be an effort")
                self.validate_effort(launcher["thinking"], location)
            args = launcher.get("args", [])
            if not isinstance(args, list) or any(
                not isinstance(argument, str) or not argument for argument in args
            ):
                raise SystemExit(f"{self.path}: {location}.args must be non-empty strings")
        outputs: set[str] = set()
        for profile_name, profile in self.profiles.items():
            if not isinstance(profile, dict):
                raise SystemExit(f"{self.path}: profile {profile_name!r} must be a mapping")
            unknown = set(profile) - {
                "output", "parent", "enabled", "defaultSubagent", "researcher",
                "title", "progress", "agents", "modelScope", "settings",
            }
            if unknown:
                raise SystemExit(f"{self.path}: unknown keys at profiles.{profile_name}: {', '.join(sorted(unknown))}")
            output = profile.get("output", profile_name)
            if not isinstance(output, str) or not re.fullmatch(r"[a-z][a-z0-9-]*", output):
                raise SystemExit(f"{self.path}: invalid profile output {output!r}")
            if output in outputs:
                raise SystemExit(f"{self.path}: duplicate Pi profile output {output}")
            outputs.add(output)
            for key in ("parent", "defaultSubagent", "researcher", "title", "progress"):
                self.validate_route(profile[key], f"profiles.{profile_name}.{key}")
            agents = profile.get("agents", {})
            if set(agents) != set(self.agent_prompts):
                raise SystemExit(f"{self.path}: {profile_name}.agents must cover all ai/agents prompts")
            for role_name, route in agents.items():
                self.validate_route(route, f"profiles.{profile_name}.agents.{role_name}")
            for model in profile.get("enabled", []):
                self.model_id(model)
        for name, source_text in self.agent_prompts.items():
            source = AI_ROOT / f"agents/{name}.md"
            if re.search(r"^(?:claude|codex)-(?:model|effort):", source_text, re.MULTILINE):
                raise SystemExit(f"{self.path}: model and effort belong in manifest profiles, not {source}")
            match = re.search(r"^tools: (.+)$", source_text, re.MULTILINE)
            if not match:
                raise SystemExit(f"{self.path}: missing tools in {source}")
            for harness in set(match.group(1).split()) & set(CLI_AGENT_PROFILES):
                profile_name, provider = CLI_AGENT_PROFILES[harness]
                location = f"profiles.{profile_name}.agents.{name}"
                if profile_name not in self.profiles:
                    raise SystemExit(f"{self.path}: {name} ships to {harness} but profiles.{profile_name} is missing")
                alias, effort = self.profiles[profile_name]["agents"][name]
                if split_model_id(self.model_id(alias))[0] != provider:
                    raise SystemExit(f"{self.path}: {location} must use a model from {provider} for {harness}")
                if effort not in CLI_EFFORTS:
                    raise SystemExit(f"{self.path}: {location} thinking {effort!r} is unsupported by {harness}")

    def agent_route(self, name: str, harness: str) -> str:
        profile_name, _ = CLI_AGENT_PROFILES[harness]
        alias, effort = self.profiles[profile_name]["agents"][name]
        _, model = split_model_id(self.model_id(alias))
        return f"{model} {effort}"

    def validate_route(self, route: Any, location: str) -> None:
        if not isinstance(route, list) or len(route) != 2:
            raise SystemExit(f"{self.path}: {location} must be [model, thinking]")
        self.model_id(route[0])
        if not isinstance(route[1], str):
            raise SystemExit(f"{self.path}: {location} requires a thinking level")
        self.validate_effort(route[1], location)

    def validate_effort(self, effort: Any, location: str) -> None:
        if effort is not None and effort not in EFFORTS:
            raise SystemExit(f"{self.path}: invalid effort {effort!r} at {location}")

    def model_id(self, alias: str) -> str:
        try:
            model = self.models[alias]
        except KeyError as exc:
            raise SystemExit(f"{self.path}: unknown model alias {alias!r}") from exc
        if not isinstance(model, dict) or not isinstance(model.get("id"), str):
            raise SystemExit(f"{self.path}: model {alias!r} requires id")
        split_model_id(model["id"])
        return model["id"]


def split_model_id(model_id: str) -> tuple[str, str]:
    provider, separator, model = model_id.partition("/")
    if not separator:
        raise SystemExit(f"invalid provider/model identifier: {model_id}")
    return provider, model


def render_catalog(manifest: Manifest) -> dict[str, Any]:
    providers: dict[str, Any] = {}
    for model in manifest.models.values():
        model_id = model["id"]
        context = model.get("context")
        if not context:
            continue
        provider, name = split_model_id(model_id)
        context_window = 272000 if context == "codex" and provider in {"openai-codex", "openrouter"} else 256000
        override = {"contextWindow": context_window}
        providers.setdefault(provider, {}).setdefault("modelOverrides", {})[name] = override
    return {"providers": providers}


def render_pi_profile(manifest: Manifest, profile: dict[str, Any]) -> dict[str, Any]:
    parent_alias, parent_effort = profile["parent"]
    parent_id = manifest.model_id(parent_alias)
    provider, parent_model = split_model_id(parent_id)
    default_alias, default_effort = profile["defaultSubagent"]
    researcher_alias, researcher_effort = profile["researcher"]
    overrides: dict[str, Any] = {
        "researcher": {
            "model": manifest.model_id(researcher_alias),
            "thinking": researcher_effort,
        }
    }
    for role_name, (alias, effort) in profile["agents"].items():
        overrides[role_name] = {
            "model": manifest.model_id(alias),
            "thinking": effort,
        }
    rendered: dict[str, Any] = {
        "defaultProvider": provider,
        "defaultModel": parent_model,
        "defaultThinkingLevel": parent_effort,
        "enabledModels": [manifest.model_id(alias) for alias in profile["enabled"]],
        "subagents": {
            "defaultModel": manifest.model_id(default_alias),
            "defaultProvider": split_model_id(manifest.model_id(default_alias))[0],
            "defaultThinking": default_effort,
            "agentOverrides": overrides,
            "modelScope": {"enforce": True, "strict": True, "allow": profile["modelScope"]},
        },
    }
    title_alias, title_effort = profile["title"]
    rendered["titleConfig"] = {
        "enabled": True,
        "model": f"{manifest.model_id(title_alias)}:{title_effort}",
        "maxTokens": 30,
        "maxLength": 60,
    }
    progress_alias, progress_effort = profile["progress"]
    rendered["progressConfig"] = {
        "model": f"{manifest.model_id(progress_alias)}:{progress_effort}",
        "maxInputChars": 12000,
        "maxTokens": 180,
        "timeoutMs": 60000,
    }
    return deep_merge(rendered, profile.get("settings", {}))


def render_outputs(manifest: Manifest) -> dict[Path, str]:
    outputs: dict[Path, str] = {}
    outputs[AI_ROOT / "pi/models.json"] = json.dumps(render_catalog(manifest), indent=2) + "\n"
    launchers = {}
    for name, launcher in manifest.pi_launchers.items():
        launchers[name] = {
            **(
                {"model": manifest.model_id(launcher["model"])}
                if "model" in launcher
                else {}
            ),
            **({"thinking": launcher["thinking"]} if "thinking" in launcher else {}),
            **({"args": launcher["args"]} if launcher.get("args") else {}),
        }
    launcher_blocks = []
    for name, launcher in launchers.items():
        fields = [
            f"    {json.dumps(key)}: {json.dumps(value)}"
            for key, value in launcher.items()
        ]
        launcher_blocks.append(
            f"  {json.dumps(name)}: {{\n" + ",\n".join(fields) + "\n  }"
        )
    outputs[AI_ROOT / "pi/launchers.json"] = (
        "{\n" + ",\n".join(launcher_blocks) + "\n}\n"
    )

    for name, profile in manifest.profiles.items():
        output = profile.get("output", name)
        outputs[AI_ROOT / f"pi/profiles/{output}.json"] = (
            json.dumps(render_pi_profile(manifest, profile), indent=2) + "\n"
        )
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--profile-output", metavar="PROFILE")
    parser.add_argument("--agent-route", nargs=2, metavar=("ROLE", "HARNESS"))
    args = parser.parse_args()
    manifest = Manifest(AI_ROOT / "manifest.yaml")
    if args.agent_route:
        role, harness = args.agent_route
        if role not in manifest.agent_prompts or harness not in CLI_AGENT_PROFILES:
            raise SystemExit(f"unknown agent route: {role}/{harness}")
        print(manifest.agent_route(role, harness))
        return 0
    if args.profile_output:
        profile_name = args.profile_output
        if profile_name not in manifest.profiles:
            raise SystemExit(f"unknown profile: {profile_name}")
        print(manifest.profiles[profile_name].get("output", profile_name))
        return 0
    outputs = render_outputs(manifest)
    stale = [path for path, content in outputs.items() if not path.exists() or path.read_text() != content]
    if args.check:
        for path in stale:
            print(f"out of date: {path.relative_to(ROOT)}", file=sys.stderr)
        return bool(stale)
    for path in stale:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(f".{path.name}.tmp")
        temporary.write_text(outputs[path])
        temporary.replace(path)
    print(f"generated {len(outputs)} AI config files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
