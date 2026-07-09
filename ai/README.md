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
