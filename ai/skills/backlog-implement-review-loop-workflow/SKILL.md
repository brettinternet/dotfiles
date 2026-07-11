---
name: backlog-implement-review-loop-workflow
description: Run the explicit one-pass backlog IMPLEMENT, REVIEW, BLOCKED, or ARCHIVE state machine with exact markers and handoff state. Use only when the user invokes this workflow or asks to continue an existing backlog implementation-review loop; do not use for ordinary feature implementation or ad hoc review.
disable-model-invocation: true
---

# Backlog Implementation-Review Loop Workflow

This is an additive skill companion to `/backlog-implement-review-loop`; the command remains available. Treat backlog paths, remote references, item selectors, and other arguments supplied with the invocation as the exact scope.

An explicit invocation requests exactly one workflow pass. It authorizes task-related edits and commits. Pushes, pull requests, remote state changes, and integration are authorized only where the supplied command/request or repository flow explicitly permits them. Never broaden that authority to unrelated work.

Stay in the active session. Do not run this skill in a forked context: source resolution, worktree state, accumulated commits, marker validity, and the final handoff must remain visible to the caller.

## Load references progressively

1. Read [sources and state](references/sources-and-state.md) before selecting work.
2. Read only the selected state in [pass procedures](references/passes.md).
3. Read [integration and handoff](references/integration-and-handoff.md) only when finishing the pass.
4. Use [the handoff template](templates/handoff.md) for the final continuation record.

During `REVIEW`, apply the `implementation-review` skill. The current workflow's scope, subagent budget, marker rules, fix authority, and integration policy override generic review defaults.

## Non-negotiable invariants

- One invocation performs one `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE` pass; it is not an internal forever loop.
- `IMPLEMENT` completes exactly one next coherent task in the first eligible scoped item.
- `REVIEW` runs only after that item's implementation sweep is complete and covers its complete accumulated implementation. It may batch other fully implemented, unreviewed scoped items when safe.
- Do not alternate implementation and review after every task.
- A review-fix commit is covered by the same review pass; do not schedule a review of the review.
- Preserve supplied source order and skip a blocked item only while its evidence-backed blocker marker remains valid.
- Work directly by default. Use at most two bounded `explore`/`executor` workers plus one oracle consultation in a pass, and never refill the budget.
- The active agent owns state selection, shared interfaces, decisions, synthesis, marker edits, integration, and handoff.
- Preserve unrelated user work and commit only task-related changes.

If the invocation supplies no resolvable backlog source or remote item, stop with the exact missing input instead of guessing.
