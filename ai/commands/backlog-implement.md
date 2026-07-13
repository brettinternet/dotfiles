---
description: Implement selected backlog items through all refined tasks, verify independently, commit, and integrate
argument-hint: <backlog-source|remote-ref> [item-ids|titles|ranges]
---

Implement the selected backlog work from `$ARGUMENTS` through its refined tasks, verify it independently, record durable progress, commit only task-related changes, and integrate each completed item using the repository's declared flow. This command owns implementation scope and authority; `backlog-source-workflow` owns provider resolution, scheduling, and durable provider operations. Accumulated implementation review belongs to `backlog-implement-review-loop` or `review-implementation`, not this command.

## Source and scope

Load `backlog-source-workflow` before interpreting `$ARGUMENTS`: read its provider-neutral contract first, resolve every explicit provider kind in supplied source order, then load one matching provider heading per resolved kind. Use `Source`, `SchedulingScope`, and `ItemState` plus `resolveSource`, `discover`, `selectNext`, `readItem`, `writeState`, `recordProgress`, and `archive`. Do not resolve a `ReviewGroup` or reproduce provider rules here.

Preserve explicit source and selector order. Selector precedence is stable provider ID, exact title, then exact description; after dependency readiness, explicit selector order wins. Provider priority/ordinal applies only within a source-only collection. Derive exactly one repository source only when no source is explicit. Never fall back from an unresolved explicit source; a missing local path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported.

Explicit selectors identify exactly the items to implement. With only a source, select the first eligible item from the whole provider collection for this invocation; later invocations recompute the collection. The default implementation boundary is one provider item. Read its complete specification, refined tasks, acceptance criteria, dependencies, blockers, durable progress, relevant code, callsites, and repository patterns before editing. Repair an unrefined or clearly oversized writable local item before coding; invoke `backlog-refine` for a remote-only item whose task boundaries need specification changes.

Before any remote-only implementation, preflight every authorized provider-native write this command may require: `implemented:` progress, `blocked:` state, status transitions, completion, and archive. If a required capability is unavailable, stop before isolation or edits with `NEXT CONTEXT REQUIRED`. Then create or switch to an isolated worktree/subtree, preserving unrelated dirty and untracked work. Stop before code changes when isolation cannot be established safely.

## Implementation and durable progress

Implement every refined task in the selected item in order. One task is one coherent behavioral outcome and includes inseparable production code, callsites, fixtures/migrations, and proving tests. After each task:

1. Run the smallest targeted verification that proves the behavior; fix in-scope failures and rerun.
2. Commit the coherent implementation without unrelated work.
3. Persist through the provider adapter the item status, completed task and commit, exact verification command/result, exact next task, and remaining acceptance criteria.
4. For remote-only items, write each applicable progress, status, blocker, completion, or archive marker through the authorized first-party operation.

If durable write-back fails, retain the coherent code commit but do not claim the task complete; leave `NEXT CONTEXT REQUIRED` with state repair as the next action. Missing code, failing item-scoped checks, or outdated tests are implementation work, not blockers. Record a blocker only for a genuinely external decision, unavailable dependency/integration, or unsafe ambiguity after safe work and verification are exhausted.

## Independent verification

When all tasks and acceptance criteria for an item appear implemented, leave it verification-pending and run one final `verifier` using the acceptance criteria, accumulated implementation commits, changed files, and verification evidence—not the active agent's conclusions. Treat every `FAIL` or `UNVERIFIED` criterion as unfinished implementation work: fix it, rerun targeted checks, and rerun the verifier. Mark the item complete only after every criterion passes and the provider durably records that evidence.

Delegate implementation only for materially substantial independent branches; keep shared interfaces, decisions, task-coupled tests, verifier synthesis, and integration in the active agent. Before recording a notable genuine blocker, gather evidence and use at most one read-only oracle consultation for that pass. Independently verify its recommendation; the active agent retains all mutation authority.

## Integration and completion

Resolve integration from repository `CLAUDE.md`, `AGENTS.md`, or backlog configuration. Otherwise use pull-request flow when push access, branch protection, or remote ownership requires it; when ambiguous, use local merge.

- `local-merge`: merge completed verified work into local `main`, clean up its temporary worktree, and do not push.
- `pull-request`: push only the task branch, open a PR with `gh`, do not merge it, report the URL, and recommend `/pr-babysit [reviewer]`.

An item is complete only when all tasks and acceptance criteria are implemented, targeted verification and the independent verifier pass, durable provider state is recorded, and the work is committed and integrated. Source-only scope is complete only when no open item remains in the whole collection. Otherwise report `NEXT CONTEXT REQUIRED` and the exact next source/item/task. Report `BACKLOG COMPLETE AND ARCHIVED` only when all scoped work and required provider archival are complete.

Start the final response with exactly one of those status lines. Report resolved source/order, selected items, completed tasks, commits, targeted checks, verifier result, durable provider receipts, integration/archive result, exact next target, preserved unrelated changes/failures, and blockers. Keep `$ARGUMENTS` unchanged in continuation prompts.
