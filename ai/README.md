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

## Pi extensions and MCP

Package sources live in `pi/profiles/common.json` and are unpinned: npm packages follow the latest release, while Git packages follow their default branch. After changing sources, rerender the active profile with `pi-profile use <name>`. Run `make update-pi` to update installed packages and refresh model catalogs.

`pi-subagents` tracks npm's `latest` tag; `pi-extensions` tracks its upstream Git repository. The subagents extension is enabled; packaged skills remain disabled. Restart Pi after updating and after owned background work has finished; creating a fresh session alone does not reload cached extensions.

Pi uses its built-in MCP support, not `pi-mcp-adapter`. Configure personal servers in `~/.pi/agent/mcp.json` and project servers in `.pi/mcp.json`; the built-in loader does not discover shared `.mcp.json` files. For a new project, copy the desired entries from `project/.mcp.json` into `.pi/mcp.json`. Run `pi mcp list` to validate connections and `/reload` after changes. MCP tools use built-in `codemode` / `tool_search` rather than the adapter's `mcp` / `mcpScript` tools.

For host-local servers shared by all Pi sessions, edit `~/.pi/agent/mcp.json` directly. This is an unmanaged local file, not a dotfiles symlink; `make ai` leaves it alone. The global Git ignore excludes `.pi/mcp.json` for untracked project-local overrides.

`pi-lsp-adapter` is retired: its fixed-delay diagnostics can report a clean file before analysis finishes or retain an error after a fix. Rerender the active profile and run `pi remove npm:pi-lsp-adapter@0.1.3` to remove an existing installation. `make ai` removes only the old dotfiles-owned `~/.pi/agent/lsp.json` link; custom configuration and runtime data are preserved. Repository lint, typecheck, and test commands remain authoritative.

### Pi directory access

The local `dcg-guard` extension restricts Bash `cd`, `rg`, and `grep` paths to the session root by default. Shell redirections to `/dev/null` (such as `2>/dev/null`) need no access grant; using it as a search path still requires one. It is a command guard, **not a filesystem sandbox**: other commands, file tools, and extensions are not confined by these path checks.

Run `/reload` once after updating the extension. Thereafter, access changes take effect immediately:

```text
/access allow /absolute/path/to/project
/access allow --permanent "/absolute/path with spaces"
/access list
/access revoke /absolute/path/to/project
/access revoke --permanent "/absolute/path with spaces"
```

Tab completion suggests subcommands, `--permanent`, and directory paths (including relative paths and `~/`). For `revoke`, it suggests saved grants in the selected scope, including missing directories. Paths containing spaces or quotes are quoted automatically.

Grants require confirmation. Blocked commands targeting an existing directory or file offer **Deny**, **Allow once** (that tool call), or **Allow for this session**. File requests grant their containing directory. Noninteractive runs cannot approve new access; use an existing grant or start Pi in the target directory. Dynamic shell paths and malformed commands remain blocked.

Session grants are saved as local Pi session entries: they survive `/reload`, resume, and context compaction, but do not transfer to another session or fork. They are session-wide, so `/tree` does not undo a revocation. With `--no-session`, they last only for that process. Custom session storage and exported transcripts may contain these paths; do not commit or share them inadvertently.

Permanent grants live in **`~/.pi/agent/access.json`**, created locally with mode `0600`, never linked or generated by dotfiles installation. Do not symlink this file into the repository. All sessions reread it on each guarded Bash call. A revoke removes the exact grant in the selected scope; a broader parent grant or a grant in the other scope still applies. `/access list` shows both scopes. Malformed storage blocks Bash until repaired. A leftover `access.json.pending` after a crash blocks permanent updates; inspect it and move it aside only after confirming no Pi process is writing it.

Approvals cover the canonical directory and its descendants, not symlink escapes. They relax only these path checks: local destructive-command policy and `dcg` checks still run. No agent-callable approval tool is registered. This is an interactive convenience policy, not protection against arbitrary code modifying local session/configuration files.

## Shared agents

The roster covers discovery (`explore`), implementation (`executor`), verification (`verifier`), review (`reviewer`), judgment (`oracle`), PR monitoring (`pr-watcher`), and explicit maintainability audits (`thermo-nuclear-code-quality-review`). Pi also keeps the builtin `researcher` for sourced web research.

Pi disables the overlapping builtin `scout`, `worker`, and `delegate` roles. It also disables the optional `claude-code`, `codex-exec`, and `cursor-agent` read-only/writer pairs: those are isolated one-shot adapters to separately installed CLIs, not native Pi roles, and duplicate this roster without supporting native model routing. They can be re-enabled in `pi/profiles/common.json` if a separate CLI subscription or runtime is intentionally needed.

Pi subagent assignments are listed explicitly in each profile's `agents` mapping; roles can share a model with different thinking levels.

Delegation policy lives in [`AGENTS.md`](AGENTS.md); role instructions and harness routing live in `agents/<role>.md`.

## Named launches

`agent` (`ai/.bin/agent`, linked by `make ai`) launches Pi by default, or Claude Code / Codex with `--kind`. It is stateless: a name is a label, not automatic resume or a durable identity registry. Native arguments go after `--`; the wrapper does not replace the native CLIs.

```sh
agent --name alice
agent --name bob --kind claude
agent --name alice -- --session-id alice # explicitly create/reopen this Pi conversation
agent --name charlie --kind codex -- resume
```

Pi and Claude receive `--name`. All children receive `AGENT_NAME`; Codex has no native `--name`, so the helper warns that only the environment and optional Herdr live name are set. The environment variable is metadata, not an instruction to the model or an authorization mechanism. With no placement flags, the helper replaces itself with the native CLI in the current terminal and preserves its exit status—even inside Herdr. It does not rename that existing Herdr pane's agent.

### Herdr placement

```sh
agent --name alice --split down
agent --name alice --tab "Auth review" # fresh tab in the caller's workspace
agent --name alice --workspace maintenance --tab review

# An explicit session works outside Herdr too, including from a scheduler.
agent --name reviewer --herdr-name "review-$(date +%s)-$$" \
  --herdr-session default --workspace maintenance --tab review \
  --cwd ~/dev/me/maintenance
```

`--workspace` is a **label**, matched together with canonical `--cwd` (default: current directory) against workspace panes, like `maintenance/scripts/noon-review.sh`. One match gets a fresh tab; no match gets a new workspace with its initial tab renamed; multiple matches fail. Existing tabs and panes are never reused for launches. `--tab` defaults to the display name when a workspace is specified. `--split` targets only the calling pane and cannot be combined with workspace, tab, or session selection.

Placement uses the inherited Herdr session unless `--herdr-session` is explicit. An explicit session requires `--workspace`, so it never falls back to another session's focused workspace. Focus is preserved unless `--focus` is supplied. Live Herdr names must match `[a-z][a-z0-9_-]{0,31}` and be unique within the selected session; `--herdr-name` separates that address from the session display name for repeated jobs. A collision fails rather than interrupting an existing agent.

Use repeatable `--env KEY` to copy exported variables into the new terminal, or `--env KEY=VALUE` to set them. Do not assume a long-running Herdr server has your scheduler's environment. `AGENT_NAME` and `HERDR_*` overrides are rejected. Values sent through Herdr's CLI may be visible in process arguments, so prefer credential files or agent-native secret lookup for stronger isolation.

For the review script, keep credential setup and prompt text there; replace its layout/start block with:

```sh
export APPRISE_URLS="pover://${PUSHOVER_USER_KEY}@${PUSHOVER_TOKEN}"
review_agent="review-$(date +%s)-$$"
agent --name reviewer --herdr-name "$review_agent" \
  --herdr-session default --workspace maintenance --tab review \
  --cwd "$project" --env APPRISE_URLS
herdr --session default agent prompt "$review_agent" "$prompt"
```

Herdr launches print the successful `agent start` JSON to stdout. Failed starts return nonzero and leave the created pane in place, reporting its ID when available; inspect it before retrying. A timeout does not prove nothing started. The helper never closes panes or resubmits work. Run the script with `set -e` (as your review script does) so a failed launch cannot proceed to prompting.

## Herdr

Herdr keeps terminal and agent processes alive across disconnects. `make ai` installs integrations for locally available agents; manage them with `herdr integration status`, `install`, and `uninstall`.
