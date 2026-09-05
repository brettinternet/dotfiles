#!/usr/bin/env python3
"""Render model catalogs and harness profiles from ai/manifest.yml."""
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
ROLE_ORDER = (
    "reviewer",
    "executor",
    "explore",
    "oracle",
    "pr-watcher",
    "thermo-nuclear-code-quality-review",
    "verifier",
    "writer",
)


def deep_merge(base: Mapping[str, Any], overlay: Mapping[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in overlay.items():
        if isinstance(merged.get(key), Mapping) and isinstance(value, Mapping):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_jsonc(path: Path) -> dict[str, Any]:
    # The base contains only line comments and trailing commas.
    lines = [line for line in path.read_text().splitlines() if not line.lstrip().startswith("//")]
    text = "\n".join(lines)
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))


class Manifest:
    def __init__(self, path: Path) -> None:
        data = yaml.safe_load(path.read_text())
        if not isinstance(data, dict) or data.get("version") != 1:
            raise SystemExit(f"{path}: expected manifest version 1")
        self.path = path
        self.roles: dict[str, Any] = data.get("roles", {})
        self.models: dict[str, Any] = data.get("models", {})
        self.profiles: dict[str, Any] = data.get("profiles", {})
        self.validate()

    def validate(self) -> None:
        for name, role in self.roles.items():
            if not isinstance(role, dict) or not role.get("route"):
                raise SystemExit(f"{self.path}: role {name!r} requires route")
            source = AI_ROOT / f"agents/{name}.md"
            if not source.is_file():
                raise SystemExit(f"{self.path}: missing agent prompt {source}")
            match = re.search(r"^omp-model: pi/(\S+)$", source.read_text(), re.MULTILINE)
            if not match or match.group(1) != role["route"]:
                raise SystemExit(
                    f"{self.path}: role {name!r} route does not match {source}'s omp-model"
                )
        outputs: set[tuple[str, str]] = set()
        for profile_name, profile in self.profiles.items():
            omp_roles = profile.get("ompRoles", {})
            for role_name, route in omp_roles.items():
                self.validate_route(route, f"profiles.{profile_name}.ompRoles.{role_name}")
            for harness, output in profile.get("outputs", {}).items():
                if harness not in {"omp", "pi", "opencode"}:
                    raise SystemExit(f"{self.path}: unknown harness {harness!r}")
                key = (harness, output)
                if key in outputs:
                    raise SystemExit(f"{self.path}: duplicate output {harness}/{output}")
                outputs.add(key)
            for harness in ("pi", "opencode"):
                config = profile.get(harness)
                if config is None:
                    continue
                for role_name in config.get("efforts", {}):
                    if role_name not in self.roles:
                        raise SystemExit(f"{self.path}: unknown agent role {role_name!r}")
                    route_name = self.roles[role_name]["route"]
                    if route_name not in omp_roles:
                        raise SystemExit(
                            f"{self.path}: {profile_name}/{harness}/{role_name} maps to missing OMP role {route_name!r}"
                        )
                for effort in config.get("efforts", {}).values():
                    self.validate_effort(effort, f"profiles.{profile_name}.{harness}.efforts")
            pi = profile.get("pi")
            if pi:
                for key in ("parent", "defaultAgent", "researcher"):
                    self.validate_route(pi[key], f"profiles.{profile_name}.pi.{key}")
                for model in pi.get("enabled", []):
                    self.model_id(model, "pi")

    def validate_route(self, route: Any, location: str) -> None:
        if not isinstance(route, list) or len(route) != 2:
            raise SystemExit(f"{self.path}: {location} must be [model, effort]")
        self.model(route[0])
        self.validate_effort(route[1], location)

    def validate_effort(self, effort: Any, location: str) -> None:
        if effort is not None and effort not in EFFORTS:
            raise SystemExit(f"{self.path}: invalid effort {effort!r} at {location}")

    def model(self, alias: str) -> dict[str, Any]:
        try:
            model = self.models[alias]
        except KeyError as exc:
            raise SystemExit(f"{self.path}: unknown model alias {alias!r}") from exc
        if not isinstance(model, dict) or not isinstance(model.get("ids"), dict):
            raise SystemExit(f"{self.path}: model {alias!r} requires ids")
        return model

    def model_id(self, alias: str, harness: str) -> str:
        model = self.model(alias)
        try:
            return model["ids"][harness]
        except KeyError as exc:
            raise SystemExit(
                f"{self.path}: model {alias!r} has no {harness} identifier"
            ) from exc

    def profile_for(self, harness: str, output: str) -> tuple[str, dict[str, Any]]:
        matches = [
            (name, profile)
            for name, profile in self.profiles.items()
            if profile.get("outputs", {}).get(harness) == output
        ]
        if len(matches) != 1:
            raise SystemExit(f"{self.path}: no unique profile for {harness}/{output}")
        return matches[0]

    def route_for_agent(self, profile: dict[str, Any], role_name: str) -> list[str]:
        route_name = self.roles[role_name]["route"]
        return profile["ompRoles"][route_name]


def split_model_id(model_id: str) -> tuple[str, str]:
    provider, separator, model = model_id.partition("/")
    if not separator:
        raise SystemExit(f"invalid provider/model identifier: {model_id}")
    return provider, model


def render_catalog(manifest: Manifest, harness: str) -> dict[str, Any]:
    providers: dict[str, Any] = {}
    for model in manifest.models.values():
        model_id = model.get("ids", {}).get(harness)
        context = model.get("context")
        if not model_id or not context:
            continue
        provider, name = split_model_id(model_id)
        context_window = 272000 if context == "codex" and provider in {"openai-codex", "openrouter"} else 256000
        if harness == "opencode":
            override = {"limit": {"context": 256000, "input": 128000, "output": 128000}}
            providers.setdefault(provider, {}).setdefault("models", {})[name] = override
        else:
            override = {"contextWindow": context_window}
            providers.setdefault(provider, {}).setdefault("modelOverrides", {})[name] = override
    return {"providers": providers}


def render_omp_profile(manifest: Manifest, profile: dict[str, Any]) -> dict[str, Any]:
    roles = {
        name: manifest.model_id(route[0], "omp")
        + (f":{route[1]}" if route[1] else "")
        for name, route in profile["ompRoles"].items()
    }
    return deep_merge({"modelRoles": roles}, profile.get("ompSettings", {}))


def render_pi_profile(manifest: Manifest, profile: dict[str, Any]) -> dict[str, Any]:
    config = profile["pi"]
    parent_alias, parent_effort = config["parent"]
    parent_id = manifest.model_id(parent_alias, "pi")
    provider, parent_model = split_model_id(parent_id)
    default_alias, default_effort = config["defaultAgent"]
    researcher_alias, researcher_effort = config["researcher"]
    overrides: dict[str, Any] = {
        "researcher": {
            "model": manifest.model_id(researcher_alias, "pi"),
            "thinking": researcher_effort,
        }
    }
    for role_name, effort in config["efforts"].items():
        route = manifest.route_for_agent(profile, role_name)
        overrides[role_name] = {
            "model": manifest.model_id(route[0], "pi"),
            "thinking": effort,
        }
    rendered: dict[str, Any] = {
        "defaultProvider": provider,
        "defaultModel": parent_model,
        "defaultThinkingLevel": parent_effort,
        "enabledModels": [split_model_id(manifest.model_id(alias, "pi"))[1] for alias in config["enabled"]],
        "subagents": {
            "defaultModel": manifest.model_id(default_alias, "pi"),
            "defaultProvider": split_model_id(manifest.model_id(default_alias, "pi"))[0],
            "defaultThinking": default_effort,
            "agentOverrides": overrides,
            "modelScope": {"enforce": True, "strict": True, "allow": config["modelScope"]},
        },
    }
    title_alias, title_effort = profile["ompRoles"]["title"]
    rendered["titleConfig"] = {
        "enabled": True,
        "model": f"{manifest.model_id(title_alias, 'pi')}:{title_effort}",
        "maxTokens": 30,
        "maxLength": 60,
    }
    return deep_merge(rendered, config.get("settings", {}))


def render_opencode_profile(manifest: Manifest, profile: dict[str, Any]) -> dict[str, Any]:
    agents: dict[str, Any] = {}
    for role_name in ROLE_ORDER:
        effort = profile["opencode"]["efforts"][role_name]
        route = manifest.route_for_agent(profile, role_name)
        agents[role_name] = {"model": manifest.model_id(route[0], "opencode")}
        if effort:
            agents[role_name]["variant"] = effort
    return {"agent": agents}


def render_outputs(manifest: Manifest) -> dict[Path, str]:
    outputs: dict[Path, str] = {}
    omp_catalog = render_catalog(manifest, "omp")
    outputs[AI_ROOT / "omp/models.yml"] = yaml.safe_dump(omp_catalog, sort_keys=False)
    outputs[AI_ROOT / "pi/models.json"] = json.dumps(render_catalog(manifest, "pi"), indent=2) + "\n"

    opencode_common = deep_merge(
        load_jsonc(AI_ROOT / "opencode/common-base.jsonc"),
        {"provider": render_catalog(manifest, "opencode")["providers"]},
    )
    outputs[AI_ROOT / "opencode/profiles/common.jsonc"] = json.dumps(opencode_common, indent=2) + "\n"

    for profile in manifest.profiles.values():
        names = profile["outputs"]
        if "omp" in names:
            outputs[AI_ROOT / f"omp/profiles/{names['omp']}.yml"] = (
                "---\n" + yaml.safe_dump(render_omp_profile(manifest, profile), sort_keys=False)
            )
        if "pi" in names:
            outputs[AI_ROOT / f"pi/profiles/{names['pi']}.json"] = (
                json.dumps(render_pi_profile(manifest, profile), indent=2) + "\n"
            )
        if "opencode" in names:
            outputs[AI_ROOT / f"opencode/profiles/{names['opencode']}.jsonc"] = (
                json.dumps(render_opencode_profile(manifest, profile), indent=2) + "\n"
            )
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--profile-output", nargs=2, metavar=("PROFILE", "HARNESS"))
    args = parser.parse_args()
    manifest = Manifest(AI_ROOT / "manifest.yml")
    if args.profile_output:
        profile_name, harness = args.profile_output
        try:
            output = manifest.profiles[profile_name]["outputs"].get(harness)
        except KeyError as exc:
            raise SystemExit(f"unknown profile: {profile_name}") from exc
        if output:
            print(output)
            return 0
        return 3
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
