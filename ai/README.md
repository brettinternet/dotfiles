# AI agent setup

Shared config for Claude Code (`~/.claude`), oh-my-pi (`~/.omp`), and Codex, installed by [`ai.yaml`](../ai.yaml). `AGENTS.md` is the global instruction file for all three. `commands/` contains shared slash-command entrypoints: OMP reads the Claude commands, while `install-codex-command-skills` generates explicit-only Codex adapters and translates their argument placeholders. Authored `skills/` packages are linked unchanged to all three tools. Agent definitions are duplicated per tool in `claude/agents/` and `pi/agents/` with identical bodies and per-tool frontmatter; Codex profiles are generated from the Claude definitions with role-specific Codex model mappings.

## Orchestration strategy

Two complementary patterns; which one is active depends only on the session model, not on config:

- **Escalation (advisor)** — a cheap/mid session does the work and escalates judgment to the `oracle` (pinned to the strongest model, fresh context). Right when the plan already exists — the command file or a refined backlog item is the decomposition. Example: `/backlog-implement` on a mid-tier session.
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

## Where each concern lives

- **Role + tier**: agent frontmatter — never inherited from the session.
- **Policy** (when to delegate/escalate/verify, the two-failure escalation ladder, don't-delegate list, subagent guard): `AGENTS.md` § Subagents, one source for all tools.
- **Workflow entrypoints**: `commands/*.md`, referencing agents by role name only and remaining model-agnostic.
- **Reusable workflow methods**: `skills/*/SKILL.md` plus optional references, templates, scripts, and source-controlled tool metadata.
- **Orchestrator tier**: chosen per session; the oracle nudge is the safety net when starting cheap.

## Commands and authored skills

- Keep command files as explicit workflow entrypoints. Codex's generated command adapters are its entrypoint; Claude and OMP use the shared command files directly.
- Keep authored skills under `ai/skills/<distinct-name>/` only for genuinely shared reusable workflow methods. `ai.yaml` links each package to `~/.claude/skills/` and `~/.agents/skills/`, and links the common directory to `~/.omp/agent/skills`.
- `install-codex-command-skills [commands-dir] [codex-skills-dir] [authored-skills-dir]` generates only Codex command adapters and rejects command/authored-skill name collisions before any generated output is written. The command file remains authoritative for its full workflow; the generated adapter is the Codex entrypoint.
- Keep optional Codex `agents/openai.yaml` metadata inside each authored skill package so the existing links carry it unchanged. The command installer never edits authored packages.

## Bounded backlog loop

OMP's `/loop` can run this command a fixed number of times as a bounded [Ralph loop](https://ghuntley.com/ralph/):

`/loop 10 /backlog-implement-review-loop path/to/backlog.md`

Every iteration starts fresh and reconstructs provider state plus active claims instead of relying on chat history. `backlog-claim` serializes cooperating agents on one host across repository worktrees: Backlog.md and GitHub use fenced item leases around CLI mutations, while loose Markdown uses one fenced source lease plus expected-hash replacement. Providers without mutation fencing, including Linear, automatically use a canonical `local-coordination` lease so work can proceed; direct first-party writes require lease/provider pre/post checks and are reported as `LOCAL COORDINATION (UNFENCED)`. Backlog.md and Linear assign unassigned work to the active provider user for visibility where supported; assignment is not the claim. Coordination-only leases neither fence provider writes nor exclude cross-host workers. Coherent handoffs checkpoint and release immediately; abandoned leases expire. Dependency waves remain authoritative, so another local session may take an independent ready root but never a dependent of unfinished or locally claimed work.

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
