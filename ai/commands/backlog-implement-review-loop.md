---
description: Run one bounded parallel implementation/review wave from a backlog
argument-hint: <backlog-source|remote-ref> [item selectors]
---

Run one fresh-context work wave for `$ARGUMENTS`. Use `backlog-source-workflow` to resolve sources, dependencies, provider state, and claims. Keep the original arguments unchanged for the next loop iteration; durable provider state, not chat history, is the handoff.

## Schedule a bounded wave

Read only enough collection state to build the earliest dependency-ready wave. Prefer work that completes an item or unlocks dependents; when impact is equal, rank eligible items by:

1. resumable implementation work
2. review-pending work or an item with an open implementation PR
3. new work from the earliest dependency-ready wave
4. a blocked item whose stale record or human decision can be resolved now

An active claim excludes that item. Never select its dependent. In an orchestrator-tier session, select up to two mutually independent, unclaimed items; in a cheap or mid-tier session, select one item and work inline. Select only one when candidates may share files, interfaces, migrations, verification state, or a source-wide claim. One invocation dispatches one fixed wave: do not replace finished workers with new ones. The next Ralph iteration gets a fresh context and recomputes the wave.

Derive the canonical claim resource through `backlog-source-workflow`. Use the same item-level resource for implementation, review, and unblock work so they cannot overlap. When the provider requires a source-wide resource, acquire that one source claim and schedule only one mutating item. The active agent acquires every required claim before delegation or isolation, retains its bearer token, heartbeats while work runs, and owns provider checkpointing and release. Claims for independent items remain independent; for an explicit atomic multi-item review, acquire the items as a bundle or do none of it.

In an orchestrator-tier session, run small or tightly coupled work inline and delegate only materially substantial, well-specified implementation or review work when an executor agent is available. Cheap and mid-tier sessions do not delegate implementation. If nothing is eligible, report active claims, dependency gates, or genuine blockers and stop.

## Delegate without absorbing worker context

The active agent owns scheduling, disjointness, claims, worker instructions, provider writes, integration ordering, and final synthesis. It does not preload full item bodies, code, diffs, logs, or test output that a worker can read directly. Delegate each selected item at most once with its source, stable ID, pass type, acceptance boundary, repository instructions, and compact handoff contract.

The entire invocation may use at most two executor agents, one final verifier, and one oracle consultation. This is a total budget, not a concurrency target; do not replace completed agents. Consult the oracle only when a blocker or completion decision depends on an unresolved architecture, security, product, or cross-item tradeoff after repository evidence is exhausted. The oracle is read-only and does not replace verification.

Workers operate independently in isolated code worktrees when they may edit code. If safe isolation is unavailable, delegate only read-only investigation and perform mutations serially. Workers must not spawn subagents, broaden beyond their assigned item, receive claim secrets, mutate backlog/provider state, or integrate. Shared provider writes and integration are serialized according to `backlog-source-workflow`.

Each worker returns only:

- item ID and pass type
- outcome and remaining work
- commit(s) and changed-file names
- checks with pass/fail status, omitting routine output
- blocker evidence or next eligible step

Do not paste full diffs, logs, item prose, or exploratory notes into the active context. Treat a missing or unverifiable checkpoint, lost claim, merge conflict, or ambiguous write as unfinished work for a later iteration.

## Implement

For an item with unfinished implementation work:

- Read the full item, acceptance criteria, existing progress, code patterns, and relevant history.
- Complete the largest coherent implementation slice that can be finished, verified, committed, and checkpointed in this worker context. Prefer completing the whole item. Multiple adjacent checklist tasks may travel together when they touch the same subsystem or verification path; stop at an interface, dependency, risky migration, unresolved decision, or other clean resumable boundary.
- Do not use checklist count as a work-size limit. If tasks are independent enough to need separate ownership or integration, leave them for later item-level passes rather than creating concurrent claims inside one item. If no checklist exists, take the smallest clear coherent slice and add stable task IDs when practical.
- Run targeted checks and fix in-scope failures.
- Commit the coherent item-related change after checks, following repository instructions and excluding unrelated work.
- Record every completed task, commit if any, verification, remaining acceptance criteria, and exact next step in the backlog provider.

Do not mark ordinary uncertainty, a failing test, or a defined unfinished prerequisite as blocked. Keep investigating or leave precise resumable progress.

## Review

When implementation tasks and acceptance criteria appear complete at scheduling time, select a review pass rather than more implementation. Do not run implementation and review concurrently for the same item.

- Resolve the exact diff from commits, branch, or PR; backlog prose is intent, not the diff.
- Review proportionately for correctness, acceptance criteria, failure paths, and tests. Use `implementation-review` for large, risky, cross-cutting, security, data, concurrency, or public-API changes.
- Fix valid findings in the same pass, rerun targeted checks, and commit coherent review fixes.
- Record what was reviewed, fixes made, checks run, and whether the item is complete or needs another implementation pass.

Do not schedule a second review solely because the review produced a fix commit.

## Unblock or wait

Refresh blocker evidence before preserving it. Clear stale or already-answered blockers under the claim. For a consequential human decision, present the evidence, a recommendation, and a small set of concrete options; persist the answer in the item before continuing on a later pass.

Mark `blocked` only when work genuinely requires a human decision, external action, explicit provider dependency, or repair of a missing/cyclic dependency reference. Record the evidence and objective unblock condition. An active claim means wait; an unfinished defined prerequisite means `ready after <item>`.

## Finish the pass

Inspect each worker commit and run proportionate verification. On lost ownership or ambiguous provider state, stop mutation and preserve safe progress; do not release an ambiguously owned claim.

Integrate successful disjoint changes one at a time, refreshing provider and repository state before each integration. Remove command-created clean worktrees after successful integration. Retain and report only dirty, conflicted, or unfinished worktrees. If one integration invalidates another worker's base or checks, leave the latter durably checkpointed for the next iteration instead of pulling its details into this context.

Before declaring any item complete, run one final verifier agent with the acceptance criteria, implementation commits, and changed files—not the workers' conclusions. Batch the wave into that one verification pass and require a compact criterion-by-criterion result; any failed or unverified criterion remains open.

While each item claim remains valid, record completed task IDs, commits, checks, verifier result, remaining work, and the exact next step in the authoritative provider. Verify that a fresh agent can resume from the provider without chat history, then release that exact claim.

Do not launch another worker wave in this invocation. Start the final response with exactly `NEXT CONTEXT REQUIRED` while scoped work remains, or `BACKLOG COMPLETE` when all scoped work is verified and durably complete. Then report the wave's selected items, pass types, commits, checks, durable outcomes, integration results, and next eligible work in a compact table or equivalent terse form. Continue the next Ralph iteration with the original `$ARGUMENTS` unchanged. Archive only when the user or provider workflow explicitly calls for it.
