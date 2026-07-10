# AI agent setup

Shared config for Claude Code (`~/.claude`), oh-my-pi (`~/.omp`), and Codex, linked by [`ai.yaml`](../ai.yaml). `AGENTS.md` is the global instruction file for all three; `commands/` are shared slash commands (OMP reads Claude user commands); agent definitions are duplicated per tool in `claude/agents/` and `pi/agents/` — identical body, per-tool frontmatter (`model`/`effort` vs `model: pi/<role>`/`thinking-level`).

## Orchestration strategy

Two complementary patterns; which one is active depends only on the session model, not on config:

- **Escalation (advisor)** — a cheap/mid session does the work and escalates judgment to the `oracle` (pinned to the strongest model, fresh context). Right when the plan already exists — the command file or a refined backlog item is the decomposition. Example: `/backlog-implement` on a mid-tier session.
- **Delegation (orchestrator)** — a smart session keeps decisions, synthesis, and shared-interface coordination, and fans volume work out to cheap pinned workers. Right when judgment is continuous: refinement, review, diagnosis. Example: `/backlog-refine` on a strong session.

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

## Where each concern lives

- **Role + tier**: agent frontmatter — never inherited from the session.
- **Policy** (when to delegate/escalate/verify, the two-failure escalation ladder, don't-delegate list, subagent guard): `AGENTS.md` § Subagents, one source for all tools.
- **Workflow shape**: `commands/*.md`, referencing agents by role name only, model-agnostic.
- **Orchestrator tier**: chosen per session; the oracle nudge is the safety net when starting cheap.

## Skills

- Claude Code looks for "fan out subagents"
- omp looks for `orchestrate`

## Model notes

- https://artificialanalysis.ai/models/gpt-5-6-luna#intelligence
- https://openrouter.ai/compare/openai/gpt-5.6-sol-pro/openai/gpt-5.6-sol/anthropic/claude-fable-5/anthropic/claude-opus-4.8

### GPT

- For coding tasks, [5.6 Luna max and 5.6 Sol medium are probably best cost per task.](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task&cost=intelligence-vs-cost-per-task)
- [Luna's speed/latency is best.](https://artificialanalysis.ai/?intelligence-efficiency=intelligence-vs-cost-per-task&agentic-speed=intelligence-vs-time-per-task#speed)
- [There's no place for 5.6 Terra](https://artificialanalysis.ai/articles/gpt-5-6-has-landed):
  > Luna and Sol are always on the Pareto frontier ahead of Terra. This means that for any Terra effort level, there is a Luna or Sol effort level that is more intelligent at no extra cost, or equally intelligent at lower cost.

### Claude

- There's no longer a place for Haiku. [5.6 Luna is cheaper and faster latency.](https://openrouter.ai/compare/openai/gpt-5.6-luna/x-ai/grok-4.5)
- [At Sonnet's price point, 5.6 Luna is a better choice](https://openrouter.ai/compare/openai/gpt-5.6-luna/anthropic/claude-sonnet-5/anthropic/claude-sonnet-4.6) (where Sonnet 4.6's performance was always good enough for planned tasks).
- In my experience, Fable is best at UI.
