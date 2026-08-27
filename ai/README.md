# AI agent setup

Shared config for Claude Code (`~/.claude`), oh-my-pi (`~/.omp`), Codex, Amp CLI (`~/.config/amp`), OpenCode (`~/.config/opencode`), and the DeepSeek Harness (`~/.dsh`), installed by [`ai.yaml`](../ai.yaml). `AGENTS.md` is the global instruction file for all six agent tools. `ai/.agents/` is the canonical source for authored shared skills and command workflows. `ai/agents/` is the canonical source for subagent definitions: one file per role holding the shared description, the per-tool model/effort tiers, and the single instruction body. `install-agents` renders the Claude, pi, OpenCode, and Codex formats from it, since their frontmatter and discovery paths differ.

## OpenCode profiles

OpenCode renders `~/.config/opencode/opencode.jsonc` from `opencode/profiles/common.jsonc` plus a selected overlay. `opencode-profile list` shows `gpt`, `claude`, `claude-gpt`, `gpt-cc-proxy`, `or`, and `or-cheap`; `opencode-profile use <name>` regenerates the local active config. Its eight global subagents mirror the pi roster; each profile supplies their OpenCode model routing. `gpt-cc-proxy` retains Meridian-backed Anthropic routing and requires `MERIDIAN_BASE_URL`. OpenCode uses neither oh-my-openagent nor OCX.

## DeepSeek Harness (dsh)

`make ai` links `~/.dsh/AGENTS.md` (global instructions), `~/.dsh/cordis.patch.yml` (home-level patch), and `~/.dsh/.agent-presets` (`ai/dsh/presets`, holding the dsh-tui `liangshen` preset) into this repo. It seeds `~/.dsh/settings.yaml` from `ai/dsh/settings.yaml` once, leaving subsequent GUI and model changes local. dsh discovers `~/.agents/skills/` natively, so the shared skills need no adapter. `make darwin` installs the dsh-tui profile with Bun (dsh's `dsh plugin` manager requires pnpm, which stays off this system); the web profile self-initializes with `dsh web`.

The settings template carries only `apiKeyEnv` references, never secrets. API keys resolve from the environment; OAuth grants (ChatGPT subscription via `openai-codex`, Claude subscription, GitHub Copilot, OpenRouter OAuth) live per-machine in `~/.dsh/.credentials.yaml` — sign in once per machine with `/login` in dsh-tui and never sync the grant. A commented provider template sits at the bottom of the settings document.

## Orchestration strategy

Two complementary patterns; which one is active depends only on the session model, not on config:

- **Escalation (advisor)** — a cheap/mid session does the work and escalates judgment to the `oracle` (pinned to the strongest model, fresh context). Right when the plan already exists — the command file or a refined backlog item is the decomposition. Example: one `/backlog-implement-review-loop` pass on a mid-tier session.
- **Delegation (orchestrator)** — a smart session keeps decisions, synthesis, and shared-interface coordination, and delegates only materially substantial, independent volume branches to cheap pinned workers under an explicit per-command budget. Small or tightly coupled work stays in the session. Right when judgment is continuous and the surface is broad: refinement, review, diagnosis.

The pipeline is deliberately asymmetric: smart refine → cheap implement → independent verify/review. Worker and oracle tiers are pinned in `ai/agents/*.md` frontmatter, so both patterns hold from any starting tier; pick the orchestrator via `/model` (Claude) or the pi profile's `modelRoles.default`.

## Agent roster

| Agent        | Tier                                                                                                          | Role                                                                 |
| ------------ | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `reviewer`   | benchmark leader where available (`Claude Opus 4.8`; OpenAI-only profiles use `GPT-5.6 Terra`)                | read-only falsification review with independently validated findings |
| `explore`    | low (`pi/smol`; Claude uses built-in Explore)                                                                 | read-only discovery, evidence gathering                              |
| `executor`   | mid (`sonnet` / `pi/task`)                                                                                    | well-specified implementation; returns questions instead of guessing |
| `verifier`   | mid (`sonnet` / `pi/task`)                                                                                    | independent acceptance check from criteria + commits; never fixes    |
| `pr-watcher` | low (`haiku` / `pi/smol`)                                                                                     | CI/review delta watching                                             |
| `oracle`     | max (`opus` / `pi/slow`, xhigh)                                                                               | second-opinion judgment: tradeoffs, diagnoses, blocker triage        |
| `writer`     | independently pinned per harness or active provider profile                                                   | final wording for externally directed messages                       |

The base roster covers the complete find/do/check/judge/watch/write loop. No tester (executor writes tests, verifier runs them skeptically) and no librarian (context7/web search cover docs).

pi and OpenCode also ship `reviewer` and `thermo-nuclear-code-quality-review`, pinned to their strongest applicable tiers. The reviewer applies the full `implementation-review` skill and tries to falsify correctness claims; the thermo-nuclear reviewer applies its dedicated maintainability rubric. Claude and Codex receive `reviewer`; Claude invokes the thermo-nuclear skill directly.

## Where each concern lives

- **Role + tier**: `ai/agents/<role>.md` frontmatter — the shared description plus each tool's model and effort, never inherited from the session. `install-agents` renders it into `~/.claude/agents/`, `~/.omp/agents/`, `~/.config/opencode/agents/`, and `~/.codex/`; OpenCode is the exception, taking its model from the active profile's `agent.<role>` entry.
- **Policy** (when to delegate/escalate/verify, the two-failure escalation ladder, don't-delegate list, subagent guard): `AGENTS.md` § Subagents, one source for all tools.
- **Workflow entrypoints**: `ai/.agents/commands/*.md` templates, rendered per tool by `install-agent-commands` as described below.
- **Reusable workflow methods**: authored `ai/.agents/skills/*/SKILL.md` packages plus optional references, templates, scripts, and source-controlled tool metadata.
- **Orchestrator tier**: chosen per session; the oracle nudge is the safety net when starting cheap.

## Writer model routing

The `user-voice` skill delegates final wording to `writer`; `draft-in-editor` reaches it through `user-voice`. The caller supplies facts, constraints, and authority, while `writer` returns wording only. User-edited drafts bypass it when read back.

Customize the model at the harness-owned routing point:

- Claude Code: `claude-model` and `claude-effort` in `ai/agents/writer.md`.
- Codex: `codex-model` and `codex-effort` in `ai/agents/writer.md`.
- OMP: `modelRoles.writer` in each `ai/pi/profiles/*.yml` overlay; the generated agent targets `pi/writer`.
- OpenCode: `agent.writer` in each `ai/opencode/profiles/*.jsonc` overlay.

Run `make ai` after changing a route. New sessions then use the regenerated global `writer` definition and active profile config.

## Shared skills and commands

- `ai/.agents/skills/<distinct-name>/` is the source for authored reusable skills. Codex, OMP, OpenCode, and Amp discover its `~/.agents/skills/` links natively; Claude receives links to the same packages at `~/.claude/skills/`.
- `ai/.agents/commands/*.md` is the source for shared slash-command workflows. `install-agent-commands` renders marked explicit-only adapters into `~/.agents/skills/` and `~/.claude/skills/`; Claude exposes the skill adapters as slash commands, while Codex, OMP, OpenCode, and Amp consume them from their native skill locations. The installer removes its legacy `~/.claude/commands/` copies so Claude does not index each workflow twice.
- `make ai` writes generated agent definitions and adapters, active profile state, and rendered profile configuration under `$HOME`; it removes only recognized legacy checkout state and explicitly retired local artifacts.
- Keep optional Codex `agents/openai.yaml` metadata inside authored skill packages; the common `.agents` links carry it unchanged.

## herdr

[herdr](https://herdr.dev/docs/) is the shared terminal multiplexer on macOS and headless Linux servers. It keeps terminal and agent processes alive after the client disconnects and exposes agent status. Tmux remains installed as a fallback and for nested sessions.

`make base` symlinks `base/.config/herdr/config.toml` to `~/.config/herdr/config.toml`, backing up an existing local file as `config.toml.dotbot-backup.<timestamp>`. One config is used locally and over SSH: keybindings are client-independent and remain useful on a remote server, so there is no separate remote config. Herdr writes configuration through the link; commit intended changes. Use `herdr server reload-config` for a running server.

`make base` also installs the external `drovr` plugin and links seven local plugins. Drovr supplies the pane and tab move actions. `brett.window-title` mirrors the focused pane title to the outer terminal. The pane collapse, equalize, and rotate plugins manage layouts. `brett.last-workspace` toggles back to the previously focused workspace, `brett.seamless-navigation` routes directional movement through Vim or tmux when needed, and `brett.command-palette` searches every installed plugin action with `fzf`. `make ai` installs integrations for locally available agent tools; check or manage them with `herdr integration status`, `install`, and `uninstall`.

## Bounded backlog loop

OMP's `/loop` can run this command a fixed number of times as a bounded [Ralph loop](https://ghuntley.com/ralph/):

`/loop 10 /backlog-implement-review-loop path/to/backlog.md`

Every iteration starts fresh and chooses one coherent implementation, review, or unblock pass from authoritative provider state. The agent claims the provider item before work, records resumable progress, and releases after verifying the checkpoint. All work on an item uses the same lease resource, while independent items in the same dependency-ready wave may proceed concurrently. Active claims mean wait or choose independent work; unfinished defined prerequisites are dependency gates, not blockers.

## Harness delegation triggers

- Claude Code recognizes "fan out subagents".
- OMP recognizes `orchestrate`.
- These phrases activate orchestration behavior before a command can apply its own conditions. Do not put them in command prompts; name optional roles only inside conditional, explicitly capped delegation policy.
- Specialized watcher delegation is bounded by the selected PR set and replaces polling rather than duplicating analysis. A final batched verifier is independent acceptance evidence, not a reason to fan out implementation.

## Model notes

- `reviewer` is manually pinned from the [BullshitBench v2 leaderboard](https://petergpt.github.io/bullshit-benchmark/viewer/index.v2.html). Accessed 2026-08-13; dataset generated 2026-07-31T22:07:20Z. Claude Opus 4.8 is first overall; GPT-5.6 Terra is the highest-ranked OpenAI model available to OpenAI-only profiles. Recheck this pin when the leaderboard or provider catalogs change.
- https://artificialanalysis.ai/models/gpt-5-6-luna#intelligence
- https://openrouter.ai/compare/openai/gpt-5.6-sol-pro/openai/gpt-5.6-sol/anthropic/claude-fable-5/anthropic/claude-opus-4.8

### `or-cheap` OpenRouter profile

- `DeepSeek V4 Pro 0813` handles default execution, implementation, verification, design, and writing. It is the newest Pro release in the live catalog and costs $1.188/M input and $3.564/M output, keeping the main worker competitive without frontier-model pricing.
- `GLM 5.3` handles planning, advice, and adversarial review. The live catalog reports 59.5 intelligence, 74.8 coding, and 59.1 agentic scores at $1.40/M input and $4.40/M output.
- `DeepSeek V4 Flash Latest` handles exploration, PR watching, titles, and commits at $0.065/M input and $0.18/M output. Its underlying release reports a 69.1 coding score, substantially ahead of the current inexpensive Nemotron Lightning and Super routes; the vision role uses the Flash Vision experiment at a time-dependent $0.22–$0.44/M input and $0.66–$1.32/M output.
- The cheapest DeepSeek first-party routes may retain prompts for training, so enforce the account's data-policy filters when repository privacy requires it. Sources accessed 2026-08-22: [OpenRouter catalog](https://openrouter.ai/models) and [OpenRouter's open-weight model review](https://openrouter.ai/blog/insights/the-open-weight-models-that-matter-june-2026/).

### GPT

- For coding tasks, [5.6 Luna max and 5.6 Sol medium are probably best cost per task.](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task&cost=intelligence-vs-cost-per-task) ([frontier models](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task&models=gpt-5-5%2Cclaude-sonnet-5%2Cgpt-5-6-luna%2Cclaude-opus-4-8%2Cclaude-4-5-haiku-reasoning%2Cgpt-5-6-terra%2Cclaude-fable-5%2Cgpt-5-6-sol%2Cgpt-5-5-pro%2Cgpt-5-6-luna-xhigh%2Cgpt-5-6-terra-medium%2Cgpt-5-6-luna-high%2Cgpt-5-6-sol-xhigh%2Cgpt-5-6-sol-high%2Cgpt-5-6-sol-medium%2Cgpt-5-6-luna-medium%2Cgpt-5-6-luna-low%2Cgpt-5-6-sol-low%2Cclaude-sonnet-5-high%2Cclaude-sonnet-5-xhigh&speed=intelligence-vs-speed&intelligence=agentic-index&total-cost=intelligence-vs-total-cost))
- [Luna's speed/latency is best](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task#speed), a probably [better choice than Haiku or Gemini Flash](https://openrouter.ai/compare/openai/gpt-5.6-luna/anthropic/claude-haiku-4.5).
- [There's no place for 5.6 Terra](https://artificialanalysis.ai/articles/gpt-5-6-has-landed):
  > Luna and Sol are always on the Pareto frontier ahead of Terra. This means that for any Terra effort level, there is a Luna or Sol effort level that is more intelligent at no extra cost, or equally intelligent at lower cost.

### Claude

- [At Sonnet's price point, 5.6 Luna is a better choice](https://openrouter.ai/compare/openai/gpt-5.6-luna/anthropic/claude-sonnet-5/anthropic/claude-sonnet-4.6) (where Sonnet 4.6's performance was always good enough for planned tasks).
- In my experience, Fable is best at UI.
