---
name: backlog-md
description: "Use when working with a Backlog.md project or its `backlog` CLI/MCP: initialize a project, create/list/view/edit/refine/archive tasks, manage dependencies or milestones, or follow the task execution workflow. Also use when authoring Backlog.md tickets so the user's checkbox, plan, acceptance-criteria, and Definition-of-Done conventions are applied."
---

# Backlog.md

Backlog.md is a provider-owned task system. Use this skill for its CLI/MCP operations and ticket authoring conventions; use `backlog-source-workflow` for source resolution, dependency scheduling, claims, authority, and durable-state semantics.

## Required operating rules

1. Resolve the source and load `backlog-source-workflow` first. For a Backlog.md source, load this skill after the matching Backlog.md provider heading.
2. Use the canonical Backlog.md control checkout for every provider read and write. An implementation worktree is code-only.
3. Prefer the documented command map in [`references/cli.md`](references/cli.md). Do not run `backlog --help` on every pass. Read `backlog instructions overview` when the project is initialized and use `--help` only when the installed version rejects a documented command, the required operation is not covered, or the capability is ambiguous.
4. Prefer `--plain` for agent-readable list/view/search output and preserve complete task bodies before editing.
5. Never edit task files directly. With the CLI, run each mutation through the selected fenced `backlog-claim exec ... -- backlog ...` path. With authorized MCP mutation, use the source workflow's coordination-only pre/post-check sequence.
6. If `backlog` is unavailable, use an authorized MCP integration or report the provider capability; do not silently substitute ad hoc Markdown edits. `bunx backlog.md <command>` is the one-off CLI fallback when dependency execution is authorized.

## Ticket checklist convention

Use three distinct checkable layers. Keep them separate because they answer different questions:

```markdown
### Implementation tasks
- [ ] T1 — one coherent behavioral outcome
- [ ] T2 — required tests and integration for that outcome

### Acceptance criteria
- [ ] AC1 — observable behavior is correct
- [ ] AC2 — relevant failure or edge state is handled

### Definition of Done
- [ ] DOD1 — targeted and independent verification passes
- [ ] DOD2 — durable progress, review evidence, and integration are recorded
```

- Implementation tasks describe the work sequence. Use stable IDs (`T1`, `T2`) and select the first unchecked task. Each task must be independently verifiable and may include inseparable production code, callsites, fixtures, migrations, and tests.
- Acceptance criteria describe externally observable or contract-level outcomes. Use stable IDs (`AC1`, `AC2`) and make each criterion testable. Do not turn implementation steps into acceptance criteria.
- Definition of Done is a final quality gate, not an implementation queue. Keep reusable project defaults short; task-specific DoD items should cover only additional risks or obligations. Do not mark the item complete until all DoD items are checked.

For Backlog.md native fields, use the provider's plan, AC, and DoD fields. Preserve the canonical `### Implementation tasks` checklist in the plan/body content. The current CLI documents `--check-ac` and `--check-dod`, but not `--check-plan`; update the full plan field under the claim when changing a plan checkbox. Use native AC/DoD check operations rather than embedding a second status system in comments or notes.

Preserve checked items and stable IDs during refinement. Never reset `[x]` to `[ ]` without explicit evidence that the task or criterion was reopened. A checked implementation task is progress, not provider completion; provider status, review, integration, and archive still require their own authorized transitions.

## Likely workflows

### Initialize or inspect a project

Use `backlog init` only when the project is not initialized. On an existing project, read the current workflow and configuration before making assumptions:

```sh
backlog instructions overview
backlog task list --plain
```

Use `backlog instructions task-creation`, `task-execution`, or `task-finalization` when a specific workflow detail is needed. Do not regenerate repository instruction files unless explicitly requested.

### Create a ticket

First decide whether the request is one coherent item or several independently verifiable items. Create the smallest useful item, then refine its description, plan, AC, and DoD before implementation. Use dependencies, parent tasks, milestones, and labels only when they improve scheduling or retrieval.

```sh
backlog task create "Concise outcome title" \
  --desc "Problem, user value, scope, and non-goals" \
  --plan "- [ ] T1 — ...
- [ ] T2 — ..." \
  --ac "AC1 — ..." \
  --ac "AC2 — ..." \
  --dod "DOD1 — ..." \
  --dod "DOD2 — ..."
```

When multiline quoting is fragile, repeat `--append-*` edits or use literal newlines; do not rely on `\n` being converted by the CLI. Quote literal backticks so the shell cannot perform command substitution. See [`references/cli.md`](references/cli.md).

### Refine before coding

Read the complete item, dependencies, repository instructions, relevant code, and history. Rewrite the plan into stable-ID task checkboxes, map every AC to one or more tasks, resolve missing references, and add only relevant DoD items. Stop for human input only on consequential product decisions that evidence cannot resolve. Persist the refined content through the provider workflow and wait for approval when the caller requests a plan-only pass.

### Implement one task at a time

Claim the item before coding. Select the first unchecked `T*` task, implement only that coherent outcome, run targeted verification, commit the code, then update the plan checkbox and durable progress under the same ownership epoch. Mark matching AC items only when their evidence is complete. Do not check DoD until all implementation tasks and AC items are complete and review/integration evidence exists.

### Review, complete, and archive

Review the accumulated implementation only after all implementation tasks are checked. Run the independent verifier, resolve findings, check the remaining AC and DoD items through guarded provider operations, record the final summary, complete the provider item, and archive only when the caller authorizes it and the provider convention requires it.

## Command reference

Load [`references/cli.md`](references/cli.md) for the compact command map, multiline and quoting rules, native checkbox operations, and the conditions for consulting live help.
