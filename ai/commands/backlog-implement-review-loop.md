---
description: Run one lease-safe implementation, review, or unblock pass from a backlog
argument-hint: <backlog-source|remote-ref> [item selectors]
---

Run one fresh-context pass for `$ARGUMENTS`. Use `backlog-source-workflow` to resolve sources, dependencies, provider state, and claims. Keep the original arguments for the next loop iteration.

## Choose one pass

Select one eligible provider item, preferring:

1. resumable implementation work
2. review-pending work or an item with an open implementation PR
3. new work from the earliest dependency-ready wave
4. a blocked item whose stale record or human decision can be resolved now

An active claim excludes that item. Another agent may take only an independent item from the same ready wave. If nothing is eligible, report the active claims, dependency gates, or genuine blockers and stop.

Claim the provider item before delegation, isolation, code edits, review fixes, or backlog mutation. Use one item-level resource for every kind of work on that item so implementation and review cannot overlap. For an explicit multi-item review, acquire the items as one bundle or do none of it.

## Implement

For an item with unfinished implementation work:

- Read the full item, acceptance criteria, existing progress, code patterns, and relevant history.
- Complete one bounded checklist task, including inseparable tests and call-site changes. If no checklist exists, take the smallest clear step and add stable task IDs when practical.
- Run targeted checks and fix in-scope failures.
- Commit the coherent item-related change after checks, following repository instructions and excluding unrelated work.
- Record the completed task, commit if any, verification, and next step in the backlog provider.

Do not mark ordinary uncertainty, a failing test, or a defined unfinished prerequisite as blocked. Keep investigating or leave precise resumable progress.

## Review

When implementation tasks and acceptance criteria appear complete, review the item's accumulated implementation or linked PR instead of starting new implementation.

- Resolve the exact diff from commits, branch, or PR; backlog prose is intent, not the diff.
- Review proportionately for correctness, acceptance criteria, failure paths, and tests. Use `implementation-review` for large, risky, cross-cutting, security, data, concurrency, or public-API changes.
- Fix valid findings in the same pass, rerun targeted checks, and commit coherent review fixes.
- Record what was reviewed, fixes made, checks run, and whether the item is complete or needs another implementation pass.

Do not schedule a second review solely because the review produced a fix commit.

## Unblock or wait

Refresh blocker evidence before preserving it. Clear stale or already-answered blockers under the claim. For a consequential human decision, present the evidence, a recommendation, and a small set of concrete options; persist the answer in the item before continuing on a later pass.

Mark `blocked` only when work genuinely requires a human decision, external action, explicit provider dependency, or repair of a missing/cyclic dependency reference. Record the evidence and objective unblock condition. An active claim means wait; an unfinished defined prerequisite means `ready after <item>`.

## Finish the pass

Before release, verify the provider contains a coherent checkpoint that a fresh agent can resume without chat history. Then release the exact item claim. Report the selected item, pass type, changes, checks, durable progress, and next eligible work. If the scoped backlog is complete, say so; archive only when the user or provider workflow explicitly calls for it.
