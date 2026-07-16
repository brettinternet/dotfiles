---
description: Run one bounded parallel implementation/review wave from a backlog
argument-hint: <backlog-source|remote-ref> [item selectors]
---

Run one fresh-context work wave for `$ARGUMENTS`, then stop. `backlog-source-workflow` owns source resolution, scheduling rules, blocker classification, and provider writes; `worklease-workflow` owns the claim lifecycle. Follow both — their rules are not restated here. Durable provider state, not chat history, is the handoff: the next iteration reruns with `$ARGUMENTS` unchanged and recomputes everything fresh.

## Select the wave

Build the earliest dependency-ready wave. Prefer work that completes an item or unlocks dependents; break remaining ties in this order:

1. resumable in-progress implementation
2. review-pending work or an item with an open implementation PR
3. new work from the earliest ready wave
4. a blocked item resolvable now (use `backlog-unblock`)

Stall guard: if provider history shows two prior attempts at the same next step with no new progress, do not retry the same approach — spend this invocation's oracle consultation on it or record a precise blocker with the evidence.

Take at most two mutually independent, unclaimed items — and only when executor agents are available and the session model is at least their tier; otherwise take one item and work it inline. Take one whenever candidates may share files, interfaces, migrations, or verification state, or the provider forces a source-wide claim. The wave is fixed at dispatch: never replace a finished worker; the next iteration reschedules.

Acquire every required claim before delegation or worktree creation, and keep heartbeats, checkpointing, and release in this session. If nothing is eligible, report the active claims, dependency gates, or genuine blockers and stop.

## Delegate lean

This session owns scheduling, claims, provider writes, integration, and synthesis. Delegate only materially substantial, well-specified passes; run small or tightly coupled work inline. Do not pull item bodies, diffs, logs, or test output into this context when a worker can read them directly.

Whole-invocation budget: at most two executors, one verifier, one oracle consultation. Delegate each item once, with its source, stable ID, pass type, acceptance boundary, repository instructions, and the return contract below. Consult the read-only oracle only for an architecture, security, product, or cross-item tradeoff still unresolved after repository evidence is exhausted.

Code-editing workers get isolated worktrees; without safe isolation, delegate only read-only investigation and mutate serially here. Workers never spawn subagents, broaden beyond their item, hold claim secrets, or touch provider state.

Workers return only: item ID, pass type, outcome, remaining work, commits and changed-file names, check pass/fail without routine output, and blocker evidence or the next step.

## Implementation pass

- Read the full item, acceptance criteria, prior progress, and the relevant code and history.
- Complete the largest coherent slice that can be finished, verified, and committed in one worker context — prefer the whole item. Stop only at a clean resumable boundary: an interface, dependency, risky migration, or unresolved decision. Checklist count is not a size limit; leave tasks needing separate ownership or integration for later item-level passes.
- Run targeted checks, fix in-scope failures, and commit the item-scoped change per repository instructions.
- Failing tests and ordinary difficulty are unfinished work, not blockers.

## Review pass

When implementation tasks and acceptance criteria look complete at scheduling time, schedule review instead of more implementation; never both concurrently for one item.

- Review the resolved diff from commits, branch, or PR — backlog prose is intent, not the diff.
- Review proportionately; use `implementation-review` for large, risky, cross-cutting, security, data, concurrency, or public-API changes.
- Fix valid findings in the same pass, rerun targeted checks, and commit.
- A review fix commit alone does not justify scheduling another review.

## Finish

Integrate successful disjoint changes serially, refreshing provider and repository state before each one. Remove clean command-created worktrees; report only dirty, conflicted, or unfinished ones. If one integration invalidates another worker's base or checks, leave that item checkpointed for the next iteration.

Before declaring any item complete, run one verifier for the whole wave with the acceptance criteria, commits, and changed files — not the workers' conclusions — and require a criterion-by-criterion result. Any failed or unverified criterion stays open.

While each claim is valid, checkpoint per `backlog-source-workflow` — recording attempts that made no progress too — verify a fresh agent could resume from the provider alone, then release. Archive only when the user or provider workflow explicitly calls for it.

Start the final response with exactly `NEXT CONTEXT REQUIRED` while scoped work remains, or `BACKLOG COMPLETE` when all scoped work is verified and durably complete. Then report the wave's items, pass types, commits, checks, durable outcomes, integration results, and next eligible work in a compact table.
