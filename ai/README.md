# AI agent setup

Shared config for Claude Code (`~/.claude`), oh-my-pi (`~/.omp`), Codex, Amp CLI (`~/.config/amp`), and OpenCode (`~/.config/opencode`), installed by [`ai.yaml`](../ai.yaml). `AGENTS.md` is the global instruction file for all five. `ai/.agents/` is the canonical source for authored shared skills and command workflows. Tool-specific agent definitions remain in `claude/agents/`, `pi/agents/`, and `opencode/agents/` because their configuration formats and discovery paths differ; Codex profiles are generated from the Claude definitions with role-specific model mappings.

## OpenCode profiles

OpenCode renders `~/.config/opencode/opencode.jsonc` from `opencode/profiles/common.jsonc` plus a selected overlay. `opencode-profile list` shows `gpt`, `claude`, `claude-gpt`, `gpt-cc-proxy`, and `openrouter`; `opencode-profile use <name>` regenerates the local active config. Its six global subagents mirror the pi roster; each profile supplies their OpenCode model routing. `gpt-cc-proxy` retains Meridian-backed Anthropic routing and requires `MERIDIAN_BASE_URL`. OpenCode uses neither oh-my-openagent nor OCX.

## Orchestration strategy

Two complementary patterns; which one is active depends only on the session model, not on config:

- **Escalation (advisor)** — a cheap/mid session does the work and escalates judgment to the `oracle` (pinned to the strongest model, fresh context). Right when the plan already exists — the command file or a refined backlog item is the decomposition. Example: one `/backlog-implement-review-loop` pass on a mid-tier session.
- **Delegation (orchestrator)** — a smart session keeps decisions, synthesis, and shared-interface coordination, and delegates only materially substantial, independent volume branches to cheap pinned workers under an explicit per-command budget. Small or tightly coupled work stays in the session. Right when judgment is continuous and the surface is broad: refinement, review, diagnosis.

The pipeline is deliberately asymmetric: smart refine → cheap implement → independent verify/review. Worker and oracle tiers are pinned in agent frontmatter, so both patterns hold from any starting tier; pick the orchestrator via `/model` (Claude) or the pi profile's `modelRoles.default`.

## Agent roster

| Agent        | Tier                                          | Role                                                                 |
| ------------ | --------------------------------------------- | -------------------------------------------------------------------- |
| `explore`    | low (`pi/smol`; Claude uses built-in Explore) | read-only discovery, evidence gathering                              |
| `executor`   | mid (`sonnet` / `pi/task`)                    | well-specified implementation; returns questions instead of guessing |
| `verifier`   | mid (`sonnet` / `pi/task`)                    | independent acceptance check from criteria + commits; never fixes    |
| `pr-watcher` | low (`haiku` / `pi/smol`)                     | CI/review delta watching                                             |
| `oracle`     | max (`fable` / `pi/slow`, xhigh)              | second-opinion judgment: tradeoffs, diagnoses, blocker triage        |

The complete find/do/check/judge/watch loop. No tester (executor writes tests, verifier runs them skeptically) and no librarian (context7/web search cover docs).

pi and OpenCode ship a sixth subagent, `thermo-nuclear-code-quality-review`, pinned to the oracle tier. It is an explicitly invoked maintainability audit outside that loop, and it applies the `thermo-nuclear-code-quality-review` skill as its rubric; Claude invokes that skill directly instead.

## Where each concern lives

- **Role + tier**: agent frontmatter — never inherited from the session.
- **Policy** (when to delegate/escalate/verify, the two-failure escalation ladder, don't-delegate list, subagent guard): `AGENTS.md` § Subagents, one source for all tools.
- **Workflow entrypoints**: `ai/.agents/commands/*.md` templates, rendered per tool by `install-agent-commands` as described below.
- **Reusable workflow methods**: authored `ai/.agents/skills/*/SKILL.md` packages plus optional references, templates, scripts, and source-controlled tool metadata.
- **Orchestrator tier**: chosen per session; the oracle nudge is the safety net when starting cheap.

## Shared skills and commands

- `ai/.agents/skills/<distinct-name>/` is the source for authored reusable skills. Codex, OMP, OpenCode, and Amp discover its `~/.agents/skills/` links natively; Claude receives links to the same packages at `~/.claude/skills/`.
- `ai/.agents/commands/*.md` is the source for shared slash-command workflows. `install-agent-commands` renders marked explicit-only adapters into `~/.agents/skills/` and `~/.claude/skills/`, and marked Claude command copies into `~/.claude/commands/`. OMP continues to read those Claude-compatible commands. Amp consumes the adapters as skills when explicitly invoked with `$<command>`.
- `make ai` writes generated adapters, active profile state, and rendered profile configuration only under `$HOME`; it never modifies the checkout. It removes only marked generated local artifacts, legacy generated Codex adapters, and the retired `~/.omp/agent/skills` link.
- Keep optional Codex `agents/openai.yaml` metadata inside authored skill packages; the common `.agents` links carry it unchanged.

## Bounded backlog loop

OMP's `/loop` can run this command a fixed number of times as a bounded [Ralph loop](https://ghuntley.com/ralph/):

`/loop 10 /backlog-implement-review-loop path/to/backlog.md`

Every iteration starts fresh and chooses one coherent implementation, review, or unblock pass from authoritative provider state. The agent claims the provider item before work, records resumable progress, and releases after verifying the checkpoint. All work on an item uses the same lease resource, while independent items in the same dependency-ready wave may proceed concurrently. Active claims mean wait or choose independent work; unfinished defined prerequisites are dependency gates, not blockers.

`worklease` provides same-host coordination among cooperating agents. It does not turn remote provider writes into cross-host fencing. Backlog.md provider state stays in the primary/control checkout; implementation worktrees contain code only.

## Harness delegation triggers

- Claude Code recognizes "fan out subagents".
- OMP recognizes `orchestrate`.
- These phrases activate orchestration behavior before a command can apply its own conditions. Do not put them in command prompts; name optional roles only inside conditional, explicitly capped delegation policy.
- Specialized watcher delegation is bounded by the selected PR set and replaces polling rather than duplicating analysis. A final batched verifier is independent acceptance evidence, not a reason to fan out implementation.

## Model notes

- https://artificialanalysis.ai/models/gpt-5-6-luna#intelligence
- https://openrouter.ai/compare/openai/gpt-5.6-sol-pro/openai/gpt-5.6-sol/anthropic/claude-fable-5/anthropic/claude-opus-4.8

### GPT

- For coding tasks, [5.6 Luna max and 5.6 Sol medium are probably best cost per task.](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task&cost=intelligence-vs-cost-per-task) ([frontier models](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task&models=gpt-5-5%2Cclaude-sonnet-5%2Cgpt-5-6-luna%2Cclaude-opus-4-8%2Cclaude-4-5-haiku-reasoning%2Cgpt-5-6-terra%2Cclaude-fable-5%2Cgpt-5-6-sol%2Cgpt-5-5-pro%2Cgpt-5-6-luna-xhigh%2Cgpt-5-6-terra-medium%2Cgpt-5-6-luna-high%2Cgpt-5-6-sol-xhigh%2Cgpt-5-6-sol-high%2Cgpt-5-6-sol-medium%2Cgpt-5-6-luna-medium%2Cgpt-5-6-luna-low%2Cgpt-5-6-sol-low%2Cclaude-sonnet-5-high%2Cclaude-sonnet-5-xhigh&speed=intelligence-vs-speed&intelligence=agentic-index&total-cost=intelligence-vs-total-cost))
- [Luna's speed/latency is best](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task#speed), a probably [better choice than Haiku or Gemini Flash](https://openrouter.ai/compare/openai/gpt-5.6-luna/anthropic/claude-haiku-4.5).
- [There's no place for 5.6 Terra](https://artificialanalysis.ai/articles/gpt-5-6-has-landed):
  > Luna and Sol are always on the Pareto frontier ahead of Terra. This means that for any Terra effort level, there is a Luna or Sol effort level that is more intelligent at no extra cost, or equally intelligent at lower cost.

### Claude

- [At Sonnet's price point, 5.6 Luna is a better choice](https://openrouter.ai/compare/openai/gpt-5.6-luna/anthropic/claude-sonnet-5/anthropic/claude-sonnet-4.6) (where Sonnet 4.6's performance was always good enough for planned tasks).
- In my experience, Fable is best at UI.
