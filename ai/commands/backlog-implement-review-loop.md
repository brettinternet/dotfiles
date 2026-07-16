---
description: Run one bounded implementation/review pass from a backlog
argument-hint: <backlog-source|remote-ref> [item selectors]
---

Run one fresh-context work pass for `$ARGUMENTS`, then stop. `backlog-source-workflow` owns source resolution, scheduling rules, blocker classification, and provider writes; `worklease-workflow` owns the claim lifecycle. Follow both — their rules are not restated here. Durable provider state, not chat history, is the handoff: the next iteration reruns with `$ARGUMENTS` unchanged and recomputes everything fresh.

## Select one item

Read only enough collection state to find the earliest dependency-ready work. Prefer work that completes an item or unlocks dependents; break remaining ties in this order:

1. resumable in-progress implementation
2. review-pending work or an item with an open implementation PR
3. new work from the earliest ready wave
4. a blocked item resolvable now (use `backlog-unblock`)

Stall guard: if provider history shows two prior attempts at the same next step with no new progress, do not retry the same approach — spend this invocation's oracle consultation on it; if an earlier iteration already consulted on this stall, record a precise blocker with the evidence instead.

Select exactly one unclaimed item and acquire its claim; keep heartbeats, checkpointing, and release in this session. If nothing is eligible, report the active claims, dependency gates, or genuine blockers and stop.

## Work the item

Run small or tightly coupled work inline. Delegate materially substantial, well-specified implementation or review to one executor when available: the worker reads the item body, code, diffs, logs, and test output directly so this context stays lean for verification and provider writes. Delegate the item at most once, with its source, stable ID, pass type, acceptance boundary, and repository instructions. If the worker returns incomplete or blocked work, continue inline or checkpoint the remainder; do not delegate again.

Whole-invocation budget: at most one executor, one verifier, one oracle consultation; when one finishes, do not start more work. Consult the read-only oracle only for an architecture, security, product, or cross-item tradeoff still unresolved after repository evidence is exhausted.

A code-editing executor works in an isolated worktree and never spawns subagents, broadens beyond the item, holds claim secrets, or touches provider state. It returns only: outcome, remaining work, commits and changed-file names, check pass/fail without routine output, and blocker evidence or the next step.

## Implementation pass

- Read the full item, acceptance criteria, prior progress, and the relevant code and history.
- Complete the largest coherent slice that can be finished, verified, and committed in this pass — prefer the whole item. Stop only at a clean resumable boundary: an interface, dependency, risky migration, or unresolved decision. Checklist count is not a size limit; leave tasks needing separate ownership or integration for later item-level passes.
- Run targeted checks, fix in-scope failures, and commit the item-scoped change per repository instructions.
- Failing tests and ordinary difficulty are unfinished work, not blockers.

## Review pass

When implementation tasks and acceptance criteria look complete at scheduling time, run a review pass instead of more implementation.

- Review the resolved diff from commits, branch, or PR — backlog prose is intent, not the diff.
- Review proportionately; use `implementation-review` for large, risky, cross-cutting, security, data, concurrency, or public-API changes.
- Fix valid findings in the same pass, rerun targeted checks, and commit.
- A review fix commit alone does not justify scheduling another review.

## Finish

Inspect the resulting commits, then integrate the change after refreshing provider and repository state. Remove a clean command-created worktree after integration; retain and report a dirty, conflicted, or unfinished one for the next iteration.

Before declaring the item complete, run one verifier with the acceptance criteria, commits, and changed files — not the worker's conclusions — and require a criterion-by-criterion result. Any failed or unverified criterion stays open.

While the claim is valid, checkpoint per `backlog-source-workflow` — recording attempts that made no progress too — verify a fresh agent could resume from the provider alone, then release. Archive only when the user or provider workflow explicitly calls for it.

Start the final response with exactly `NEXT CONTEXT REQUIRED` while scoped work remains, or `BACKLOG COMPLETE` when all scoped work is verified and durably complete. Then report the item, pass type, commits, checks, durable outcome, integration result, and next eligible work in a compact table or equivalent terse form.
