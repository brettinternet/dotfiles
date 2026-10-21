# AI agent setup

Shared config for Claude Code, Pi, Codex, and Amp. Off by default; select per machine in `~/.envrc`:

```sh
export DOTFILES_AI_TOOLS=all   # or pi,claude,codex,amp | none
make ai                        # install/refresh; deselected tools are removed
make uninstall-ai              # remove everything managed; local settings kept
```

Any selection installs the `dcg` destructive-command guard.

## Layout

| Path | Purpose |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | shared instructions and delegation policy |
| `manifest.yaml` | models, launchers, per-profile model assignments |
| `agents/<role>.md` | subagent prompts → `~/.{pi/agent,claude,codex}/agents/` |
| `.agents/skills/`, `.agents/commands/` | skills (commands render as skills) |
| `pi/`, `claude/`, `amp/` | harness config |
| `project/` | project defaults (e.g. `.mcp.json`) |

Generated files are outputs: edit the source here, then `make ai` or `ai-config generate`.

## Profiles and launchers

```sh
ai-config use codex           # ChatGPT subscription models
ai-config use openrouter      # needs OPENROUTER_API_KEY
ai-config generate --check

p list
p fast
p oracle --no-session "Review this design"
p solo --continue             # no subagent tools
```

In `manifest.yaml`, models are `[alias, thinking]`:

```yaml
profiles:
  codex:
    parent: [codex-astra, medium]        # interactive model
    enabled: [codex-luna, codex-sol]     # model cycling
    defaultSubagent: [codex-sol, high]
    agents:
      reviewer: [codex-astra, high]      # standalone Codex/Claude agents use these too
```

## Pi packages and MCP

```sh
pi-profile use <name>         # after editing pi/profiles/common.json
make update-pi                # update packages + model catalogs, then restart Pi
pi mcp list                   # then /reload
```

MCP servers: `~/.pi/agent/mcp.json` (personal, unmanaged) or `.pi/mcp.json` (project, git-ignored). Shared `.mcp.json` is not read; copy entries from `project/.mcp.json`.

## Directory access

`dcg-guard` limits Bash `cd`/`rg`/`grep` to the session root. It is a command guard, **not a sandbox**.

```text
/access allow /abs/path
/access allow --permanent "/abs/path with spaces"   # ~/.pi/agent/access.json
/access list
/access revoke /abs/path
```

Blocked commands prompt **Deny / Allow once / Allow for this session**. Session grants survive `/reload` and resume, not forks.

## Agents

`explore`, `executor`, `verifier`, `reviewer`, `oracle`, `pr-watcher`, `thermo-nuclear-code-quality-review`, plus Pi's `researcher`.

## Named launches

```sh
agent alice                           # Pi in this terminal
agent bob -k claude                   # or -k codex
agent alice -- --session-id alice     # native args after --
agent alice -s down                   # Herdr split
agent "Auth review" -t                # new tab
agent alice -w maintenance -t review  # workspace by label + cwd
agent alice -w maintenance -t review --reuse-pane   # replace alice
agent alice -t -p 'Review this diff' --close-on-done
agent alice -t -p 'Review this diff' --wait          # until process exits
agent alice -t -e APPRISE_URLS -n     # dry-run JSON plan
agent --list | --status alice | --close alice
```

Use `-p`, not a native prompt arg, with Herdr placement. `--wait` returns 0 on exit; it is not a success code. Ctrl-C detaches; SIGTERM under `--wait` closes the pane. For non-agent commands use `pane`. See `agent --help`.

Scheduled jobs (Noon):

```sh
agent-job launch review '/skill:pr-review repo:{repo} author:{env:AUTHORS}' \
  "gh pr list --json number,headRefOid --jq 'if length == 0 then empty else tojson end'"
agent-job launch --daily babysit '/skill:pr-babysit-loop'
agent-job close review
```

The gate prints a work fingerprint; empty or unchanged output skips the run. Focused panes are never closed.

The Noon PR review job asks the agent to append each completed review's GitHub PR URL to
`.git/noon/reviews/YYYY-MM-DD.log` (local completion date), one link per line. The path is resolved
from Git's common directory so worktrees share the repository's logs. This includes `WAIT` decisions
but excludes skipped or failed reviews. Files are append-only and retained across days.

## Herdr

```sh
herdr integration status      # make ai installs available integrations
```
