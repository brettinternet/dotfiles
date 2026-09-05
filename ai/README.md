# AI agent setup

Shared configuration for Claude Code, Pi, Oh My Pi (OMP), Codex, Amp, OpenCode, and the DeepSeek Harness (dsh). Install or refresh it with:

```sh
make ai
```

[`ai.yaml`](../ai.yaml) links configuration into each tool's home directory. [`AGENTS.md`](AGENTS.md) provides shared instructions.

## Sources

- `manifest.yaml` — central model catalog, profile routing, and cross-harness role mapping; `generate-config.py` renders harness-specific sources
- `agents/` — shared subagent prompts; `install-agents` renders harness-specific definitions
- `.agents/skills/` — reusable skills discovered through `~/.agents/skills/`
- `.agents/commands/` — shared workflows rendered as skills by `install-agent-commands`
- `pi/`, `omp/`, `opencode/`, `claude/`, `amp/`, and `dsh/` — harness-specific configuration
- `project/` — project-level defaults

Generated files under `$HOME` should not be edited directly. Change their source here and rerun `make ai`.

## Profiles

```sh
ai-config use codex       # all supported harnesses
ai-config use openrouter  # or: claude, codex-claude, openrouter-cheap, copilot, personal
ai-config generate --check
```

The individual `pi-profile`, `omp-profile`, and `opencode-profile` commands remain available. Generated profile and model files under `pi/`, `omp/`, and `opencode/` should not be edited directly; change `manifest.yaml` and run `ai-config generate`.

- **Pi:** combines `pi/profiles/common.json` with the selected generated overlay. `codex` uses ChatGPT subscription models; `or` requires `OPENROUTER_API_KEY`.
- **OMP:** remains independently configured under `omp/`.
- **OpenCode:** combines `opencode/profiles/common.jsonc` with an overlay. Run `opencode-profile list` for available profiles.
- **dsh:** links global instructions, presets, and a settings template. API keys come from environment variables; OAuth credentials remain machine-local in `~/.dsh/.credentials.yaml`.

`manifest.yaml` owns model metadata and role-to-model routing. OMP's richer `modelRoles` vocabulary is canonical: shared agents map through it (for example, `oracle` maps to `slow`), while Pi-specific `title` and `progress` routes render their model configs. OMP-only roles remain OMP-only. Harness profile names are mapped by the manifest, such as central `codex` to OpenCode `gpt`.

## Shared agents

The roster covers discovery (`explore`), implementation (`executor`), verification (`verifier`), review (`reviewer`), judgment (`oracle`), PR monitoring (`pr-watcher`), external wording (`writer`), and explicit maintainability audits (`thermo-nuclear-code-quality-review`). Pi also keeps the builtin `researcher` for sourced web research.

Pi disables the overlapping builtin `scout`, `worker`, and `delegate` roles. It also disables the optional `claude-code`, `codex-exec`, and `cursor-agent` read-only/writer pairs: those are isolated one-shot adapters to separately installed CLIs, not native Pi roles, and duplicate this roster without supporting native model routing. They can be re-enabled in `pi/profiles/common.json` if a separate CLI subscription or runtime is intentionally needed.

Pi profile overlays route the active roster by task shape:

| Role                                 | `codex`      | `or`                    |
| ------------------------------------ | ------------ | ----------------------- |
| `explore`, `pr-watcher`              | Luna, low    | Luna, low               |
| `researcher`                         | Luna, medium | Luna, medium            |
| `executor`, `verifier`               | Luna, max    | Luna, max               |
| `reviewer`                           | Terra, max   | Claude Opus 4.8, xhigh  |
| `oracle`                             | Sol, max     | Claude Fable, high      |
| `thermo-nuclear-code-quality-review` | Sol, max     | Sol Pro, xhigh          |
| `writer`                             | Terra, low   | Claude Opus 4.6, medium |

Delegation policy lives in [`AGENTS.md`](AGENTS.md); role instructions and harness routing live in `agents/<role>.md`.

## Herdr

Herdr keeps terminal and agent processes alive across disconnects. `make ai` installs integrations for locally available agents; manage them with `herdr integration status`, `install`, and `uninstall`.
