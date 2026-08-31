---
description: Implement and review one backlog item until complete
argument-hint: <backlog-source|remote-ref> [item selectors]
---

Select exactly one backlog item for `$ARGUMENTS`, own it through implementation, review, verification, integration, and durable provider completion, then stop. `backlog-source-workflow` owns source resolution, scheduling rules, blocker classification, and provider writes. Durable provider state, not chat history, is the handoff if a genuine external or human-required blocker prevents completion; otherwise the selected item must be complete before this invocation ends.

## Select one item

Read only enough collection state to find the earliest dependency-ready work. Prefer work that completes an item or unlocks dependents; break remaining ties in this order:

1. resumable in-progress implementation
2. review-pending work or an item with an open implementation PR
3. new work from the earliest ready wave
4. a blocked item resolvable now (use `backlog-unblock`)

Stall guard: if provider history shows two prior attempts at the same next step with no new progress, do not retry the same approach — spend this invocation's oracle consultation on it; if an earlier iteration already consulted on this stall, record a precise blocker with the evidence instead.

Select exactly one unclaimed item and acquire its claim; keep heartbeats, checkpointing, and release in this session. If nothing is eligible, report the active claims, dependency gates, or genuine blockers and stop.

## Complete the item

The selected backlog item is the only unit of work and the only normal stopping boundary. Checklist entries, code areas, execution slices, review findings, and intermediate commits stay within this invocation. Do not checkpoint merely because the next step is substantial or a coherent slice has landed; continue until every acceptance criterion is implemented, reviewed, verified, integrated, and recorded complete.

Run small or tightly coupled work inline. Delegate materially substantial, well-specified implementation or review to one executor when available: the worker reads the item body, code, diffs, logs, and test output directly so this context stays lean for verification and provider writes. Delegate the item at most once, with its source, stable ID, acceptance boundary, and repository instructions. If the worker returns incomplete work, continue inline; checkpoint the remainder only when a genuine external or human-required blocker prevents further progress.

Whole-invocation budget: at most one executor, one verifier, one oracle consultation. Consult the read-only oracle only for an architecture, security, product, or cross-item tradeoff still unresolved after repository evidence is exhausted. Finishing one phase does not start another backlog item.

A code-editing executor works in an isolated worktree and never spawns subagents, broadens beyond the item, holds claim secrets, or touches provider state. It returns only: outcome, remaining work, commits and changed-file names, check pass/fail without routine output, and blocker evidence or the next step.

When this command creates the implementation worktree itself, prefer `hwt create --branch <branch> --base <base> --json` when HWT and a Herdr server are available, then pass the returned path to the executor; the executor must not create a second worktree. Use harness-provided isolation as-is, and fall back to `git worktree` only for exact-SHA detached work or when HWT/Herdr is unavailable.

## Implementation pass

- Read the full item, acceptance criteria, prior progress, and the relevant code and history.
- Implement the whole item. Split execution into internal steps when useful, but do not treat checklist count, subsystem boundaries, risky migrations, or ordinary difficulty as reasons to defer item-scoped work to another invocation.
- Run targeted checks, fix every in-scope failure, and commit the item-scoped change per repository instructions.
- Failing tests and ordinary difficulty are unfinished work, not blockers. Stop incomplete only when a genuine external or human-required prerequisite remains after every reachable part is finished and verified.

## Review pass

After implementation tasks and acceptance criteria are complete, review the resolved item diff in the same invocation.

- Review proportionately. Use `implementation-review` only for a completed item with large, risky, cross-cutting, security, data, concurrency, or public-API changes; do not invoke it for partial slices or tiny routine changes.
- Fix valid findings in the same invocation, rerun targeted checks, and commit.
- Review fixes remain part of the selected item and do not justify another pass or context.

## Finish

Inspect the resulting commits, then integrate the completed item after refreshing provider and repository state. Remove a clean command-created worktree after integration using the creator's lifecycle command; for HWT, use `hwt remove --workspace <workspace-id> --json`. Retain and report a dirty or conflicted worktree only when a genuine blocker prevents safe completion.

Before declaring the item complete, run one verifier with the acceptance criteria, commits, and changed files — not the worker's conclusions — and require a criterion-by-criterion result. Any failed or unverified criterion stays open. Record a substantive excess observation as follow-up work on an existing backlog item that covers it, or a new item if none does; it never blocks completing this item.

While the claim is valid, checkpoint per `backlog-source-workflow`, verify a fresh agent could resume from the provider if blocked, then release. Mark the selected item complete only after implementation, review, verification, and integration all succeed. Archive only when the user or provider workflow explicitly calls for it.

Start the final response with exactly `NEXT CONTEXT REQUIRED` when the selected item is complete but more scoped backlog work remains, or `BACKLOG COMPLETE` when all scoped work is verified and durably complete. If a genuine blocker leaves the selected item incomplete, use `NEXT CONTEXT REQUIRED` and report the precise durable blocker. Then report the item, commits, checks, durable outcome, integration result, and next eligible work in a compact table or equivalent terse form.
