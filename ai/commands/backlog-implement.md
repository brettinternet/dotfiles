---
description: Implement selected backlog items through all refined tasks, verify independently, commit, and integrate
argument-hint: <backlog-source|remote-ref> [item-ids|titles|ranges]
---

Implement the selected backlog work from `$ARGUMENTS` through its refined tasks, verify it independently, record durable progress, commit only task-related changes, and integrate each completed item using the repository's declared flow. This command owns implementation scope and authority; `backlog-source-workflow` owns provider resolution, scheduling, and durable provider operations. Accumulated implementation review belongs to `backlog-implement-review-loop` or `review-implementation`, not this command.

## Source and scope

Load `backlog-source-workflow` before interpreting `$ARGUMENTS`: read its provider-neutral contract first, resolve every explicit provider kind in supplied source order, then load one matching provider heading per resolved kind. Use `Source`, `SchedulingScope`, `ItemState`, and `WorkClaim` plus `resolveSource`, `discover`, `selectNext`, `readItem`, claim/heartbeat/release, fenced `writeState`/`recordProgress`, and `archive`. Use the selected provider's native reads/writes and claim authority; do not resolve a `ReviewGroup` or reproduce provider rules here.

Preserve explicit source and selector order. Build the complete dependency graph before selection; an incomplete, blocked, missing, or cyclic prerequisite is a hard gate. Selector order wins within a dependency-ready wave, while provider priority/ordinal applies only within a source-only wave. Derive exactly one repository source only when no source is explicit. Never fall back from an unresolved explicit source; a missing local path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported.

Explicit selectors identify exactly the items to implement. With only a source, select the first claimable item from the earliest dependency-ready wave. An active claim may be bypassed only for an independent item in that same wave, never for its dependent; unclaimed or expired-claim in-progress work ranks before new work. If all scoped roots are terminal, blocked, or actively claimed, perform no implementation and report complete/blocker/claim-owner-expiry state. The default implementation boundary is one provider item.

Before implementation context, isolation, delegation, or edits, preflight authorized writes and require adapter capability `item-claim` or fenced `source-claim`; `none` stops work. For same-host Backlog.md/GitHub/loose-Markdown adapters, derive the `backlog-claim` resource, refresh provider state plus local claim state, generate unique claim/session/worker-attempt IDs, and acquire `implement-item:<item-id>:<next-task>:<provider-version>`. Backlog.md then projects `@<assignee>` through a guarded task edit. Linear requires a complete native fenced integration and otherwise stops. Reread ambiguous acquisition by exact claim ID; revalidate dependencies after acquisition, then read the full specification/tasks/acceptance/progress/code/callsites, repair writable local refinement or invoke `backlog-refine` remotely, and create isolated work.

## Implementation and durable progress

Implement every refined task in the claimed item in order. One task includes inseparable production code, callsites, fixtures/migrations, and proving tests. The holder revalidates dependencies and heartbeats by claim ID/token/current revision before half the lease elapses and around long checks/integration. After each task:

1. Run the smallest targeted verification; fix in-scope failures and rerun.
2. Commit the coherent implementation without unrelated work.
3. With the current ownership epoch, persist status, completed task/commit, exact verification, next task, and remaining acceptance criteria.
4. Fence every progress/status/blocker/completion/archive mutation with the current claim ID/token/revision: `backlog-claim exec` for one Backlog.md/GitHub CLI mutation or `backlog-claim replace-file` for one loose-Markdown source CAS. Retain the provider result and updated claim receipt.

The active agent owns the claim; children do not. Heartbeat before half the lease elapses and around long work; guarded CLI execution renews while its child runs. Expiry, replacement, file-version conflict, or reopened dependency stops provider mutation/integration. Ambiguous ownership is resolved by rereading the exact claim ID, never adoption. Failed write-back retains the code commit and claim until repaired/expired. Persist a genuine blocker or coherent early-handoff checkpoint under the current epoch, then release with current token/revision; `in-progress` remains immediately resumable by a fresh claim.

## Independent verification

When all tasks/acceptance appear implemented, leave the claimed item verification-pending and run one final `verifier` from criteria, commits, files, and evidence. Every `FAIL`/`UNVERIFIED` remains implementation work. Mark complete only after all pass and provider evidence is durable through the current claim ID/token/revision guard.

Delegate implementation only for materially substantial independent branches; keep shared interfaces, decisions, task-coupled tests, verifier synthesis, and integration in the active agent. Before recording a notable genuine blocker, gather evidence and use at most one read-only oracle consultation for that pass. Independently verify its recommendation; the active agent retains all mutation authority.

## Integration and completion

Resolve integration from repository `CLAUDE.md`, `AGENTS.md`, or backlog configuration. Otherwise use pull-request flow when push access, branch protection, or remote ownership requires it; when ambiguous, use local merge.

- `local-merge`: merge completed verified work into local `main`, clean up its temporary worktree, and do not push.
- `pull-request`: push only the task branch, open a PR with `gh`, do not merge it, report the URL, and recommend `/pr-babysit [reviewer]`.

An item is complete only when tasks/acceptance, targeted verification, independent verifier, integration, guarded provider completion, and `releaseClaim` succeed. Source-only scope completes only with no open item or active claim. Otherwise report `NEXT CONTEXT REQUIRED` with next task, blocking roots, and active claim owners/expiries plus gated chains. Use `BACKLOG COMPLETE AND ARCHIVED` only after all scoped work/archive is complete.

Report status first, then source order, selected item/wave, tasks, claim ID/owner/work key/revision/expiry and receipts, commits/checks/verifier, durable writes, integration/archive, next target, unrelated changes/failures, blockers, and active claims. Continue with unchanged `$ARGUMENTS`.
