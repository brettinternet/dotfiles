# AI agent setup

Shared configuration for Claude Code, Pi, Codex, and Amp.

AI tools are disabled by default. Select them per machine in `~/.envrc`, then install or refresh them:

```sh
export DOTFILES_AI_TOOLS=all
# Or select a subset: pi,claude,codex,amp
make ai
```

The comma-separated selector also accepts `none`. Any non-empty selection installs the fail-closed destructive-command guard (`dcg`). Removing a tool from the selector removes managed links and generated agent definitions, then uninstalls its Mise package; mutable local settings are preserved.

To completely remove the AI group, including its helper links, generated profiles, guards, integrations, Mise configuration, and installed packages, run:

```sh
make uninstall-ai
```

Unmanaged files and mutable local settings are preserved.

[`ai.yaml`](../ai.yaml) links configuration into each selected tool's home directory. [`AGENTS.md`](AGENTS.md) provides shared instructions.

## Sources

- `manifest.yaml` — Pi model catalog, launchers, and per-profile model assignments (also used for Claude Code and Codex CLI agents); `generate-config.py` renders Pi settings and model overrides
- `agents/` — shared subagent prompts; `install-agents` renders harness-specific definitions
- `.agents/skills/` — reusable skills discovered through `~/.agents/skills/`
- `.agents/commands/` — shared workflows rendered as skills by `install-agent-commands`
- `pi/`, `claude/`, and `amp/` — harness-specific configuration
- `project/` — project-level defaults

Generated files under `$HOME` should not be edited directly. Change their source here and rerun `make ai`. Claude preferences from `claude/settings.json` are merged into the mutable user settings on each run, preserving local-only keys such as integration hooks.

## Profiles

```sh
ai-config use codex       # Pi profile
ai-config use openrouter  # or: claude; renders to the `or` Pi profile
ai-config generate --check
```

The `pi-profile` command remains available. Generated profile and model files under `pi/` should not be edited directly; change `manifest.yaml` and run `ai-config generate`.

Use `p <launcher> [pi arguments...]` for a manifest-backed Pi launch preset, or `p list` to show presets. Launchers can configure a model, thinking level, arbitrary Pi arguments, or any combination:

```sh
p fast
p oracle --no-session "Review this design"
p solo --continue # use the active profile defaults without subagent tools
```

Pi combines `pi/profiles/common.json` with the selected generated overlay. `codex` uses ChatGPT subscription models; `or` requires `OPENROUTER_API_KEY`. In `manifest.yaml`, each `[alias, thinking]` pair identifies a Pi model from `models` and its thinking level. `parent` is the interactive Pi model; `defaultSubagent` is the fallback for subagents without an override; `researcher` configures the built-in research subagent; `agents` assigns each named subagent its model and thinking level. `title` and `progress` configure the separate Pi title and progress extensions. `enabled` controls interactive model cycling, while `modelScope` restricts subagent model choices. Agent instructions come from `ai/agents/<role>.md`; `install-agents` generates definitions under `~/.pi/agent/agents/`, `~/.claude/agents/`, and `~/.codex/agents/`. Pi agents take their models from the active profile's `agents` mapping. Standalone Claude Code and Codex CLI agents take theirs from the `claude` and `codex` profiles' `agents` mappings, with the provider prefix removed, so each role's model is defined once per provider.

## Shared agents

The roster covers discovery (`explore`), implementation (`executor`), verification (`verifier`), review (`reviewer`), judgment (`oracle`), PR monitoring (`pr-watcher`), external wording (`writer`), and explicit maintainability audits (`thermo-nuclear-code-quality-review`). Pi also keeps the builtin `researcher` for sourced web research.

Pi disables the overlapping builtin `scout`, `worker`, and `delegate` roles. It also disables the optional `claude-code`, `codex-exec`, and `cursor-agent` read-only/writer pairs: those are isolated one-shot adapters to separately installed CLIs, not native Pi roles, and duplicate this roster without supporting native model routing. They can be re-enabled in `pi/profiles/common.json` if a separate CLI subscription or runtime is intentionally needed.

Pi subagent assignments are listed explicitly in each profile's `agents` mapping; roles can share a model with different thinking levels.

Delegation policy lives in [`AGENTS.md`](AGENTS.md); role instructions and harness routing live in `agents/<role>.md`.

## Herdr

Herdr keeps terminal and agent processes alive across disconnects. `make ai` installs integrations for locally available agents; manage them with `herdr integration status`, `install`, and `uninstall`.
