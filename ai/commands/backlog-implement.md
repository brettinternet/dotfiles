---
description: Implement selected backlog items through all refined tasks, verify independently, commit, and integrate
argument-hint: <backlog-source|remote-ref> [review-group:<provider-native-selector>] [item-ids|titles|ranges]
---

Implement the selected backlog work from `$ARGUMENTS` through its refined tasks, verify it, record durable progress, commit only task-related changes, and integrate the completed item(s) using the repository's declared flow. This command is an authority and scope entrypoint; source resolution, provider operations, and durable provider state are owned by the `backlog-source-workflow` skill.

## Required source workflow

Load and follow `backlog-source-workflow` before interpreting `$ARGUMENTS` or reading backlog content: read its provider-neutral contract first, resolve every provider kind represented by the explicit sources, then load one matching provider heading per resolved provider kind, preserving explicit source order when those kinds differ. Use its `Source`, `SchedulingScope`, `ItemState`, and optional `ReviewGroup` values plus `resolveSource`, `discover`, `selectNext`, `readItem`, `writeState`, `recordProgress`, `reviewBoundary`, and `archive`; do not reproduce provider-resolution, storage, or mutation rules here.

Pass the original `$ARGUMENTS` to source resolution unchanged. Explicit sources resolve first and win across unrelated sources; preserve every supplied source and selector in argument order. For explicit item selectors, precedence is stable provider ID, then exact title, then exact description; after dependency readiness, that explicit selector order wins. Apply provider priority/ordinal only within a source-only collection. If no source is explicit, resolve exactly one unambiguous repository-derived source; report ambiguity or missing integration instead of guessing. A source-only input means the whole resolved provider collection is in scope for scheduling, not one hard-coded file or the first item forever. On each fresh invocation, schedule across that whole collection and recompute dependency readiness, blockers, status, and provider priority/order before selecting work. Never silently add a source or selector.
If an explicit source or selector cannot resolve, report that argument and candidates; never fall back to another or derived source.

The skill owns provider-specific behavior. In particular, Backlog.md discovery and task/notes/status/acceptance-criteria/final-summary/archive mutations use its `backlog` CLI or MCP adapter whenever an operation exists; GitHub Issues use `gh`; Linear uses its first-party integration; loose Markdown follows its existing direct-edit convention. Do not edit provider storage directly or create a parallel local state store. Remote-only progress is written through the authorized provider operation.

## Scope and selection

- Explicit item IDs, titles, descriptions, or ranges select exactly those items, in original argument/source order; process every selected item through every refined task. An explicit `review-group:<provider-native-selector>` is passed unchanged to `reviewBoundary` and selects only the provider-authorized group members for review; it never widens implementation scope or turns source-only scheduling into source-wide review.
- With only a source, schedule the first eligible item returned by the skill's whole-collection scheduler for this invocation. Later invocations revisit the entire collection, so a blocked or dependency-ineligible item does not permanently hide later ready work.
- The default implementation boundary is one provider item. A milestone, epic, parent, or other multi-item implementation batch is allowed only when explicitly selected by the caller and represented by the skill's durable scope; do not infer a batch from a source-only input.
- Read the selected item(s), all refined tasks and acceptance criteria, dependency/blocker evidence, relevant code, and existing durable progress before editing. Refinement task boundaries are authoritative. Repair an unrefined or clearly oversized writable local item before coding; invoke `backlog-refine` for a remote-only item that requires task-boundary changes.
  Validate every explicit local path before isolation. A missing explicit path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and must report the substitution; otherwise stop before any edit rather than falling back to another or derived source.
  Before any remote-only invocation creates or switches to a worktree/subtree or makes an implementation edit, determine the provider-native durable writes that this invocation may require—`implemented:` progress, applicable `reviewed:` evidence, `blocked:` state, status transitions, completion, and archive—and preflight every corresponding authorized first-party operation. If any required capability is unavailable or its preflight fails, stop before isolation or edits and leave `NEXT CONTEXT REQUIRED`; a handoff or final response is not durable state. Otherwise create or switch to an isolated worktree or subtree. Preserve unrelated dirty and untracked user work in the original worktree; never claim, overwrite, or commit it. If isolation cannot be established safely, stop before code changes and report the exact reason.
- Preserve unrelated dirty work and do not claim or commit it. A missing implementation path is not by itself a blocker; resolve moved/generated/prerequisite/created paths using repository evidence before stopping.

## Implementation boundary and durable progress

For each selected item, implement every refined task in order. Each task is one coherent behavioral outcome and includes inseparable production code, callsites, fixtures/migrations, and tests. After every task, run the smallest targeted verification, commit the coherent implementation, and use the skill's provider adapter to persist:

- item status (`in-progress`, `verification-pending`, `blocked`, or `complete`, using source vocabulary)
- completed task and implementation commit
- exact verification command and result
- exact next task and remaining acceptance criteria

For remote-only items, post each applicable progress, status, blocker, completion, or archive marker through the authorized first-party provider operation; include `reviewed:` when the caller explicitly requests review. If provider write-back fails, do not claim the pass complete; retain the code commit and leave `NEXT CONTEXT REQUIRED` with repair as the next action. A blocker is valid only for a genuinely external decision, unavailable dependency/integration, or unsafe ambiguity after all safe in-scope work and verification failures have been addressed. Record the attempted paths and exact unblock condition, then stop or continue with the next explicitly selected item according to the skill's blocker rules.

When all tasks and acceptance criteria for an item are implemented, leave the provider state verification-pending, run the final verification required by the skill, and mark it complete only after that evidence is recorded. A review marker is not required by this command unless the caller explicitly requests review; the review-loop command owns accumulated item review.

## Verification and delegation

Use targeted tests, typecheck, build, migration checks, or manual QA appropriate to the changed behavior. Fix in-scope failures and rerun; report unrelated failures without changing them. Do not claim project-wide health when it was not checked. Delegate only materially substantial independent branches within the command's available budget; keep shared interfaces, decisions, task-coupled tests, and integration in the active agent. Skip formatters, linters, and project-wide suites when the caller requests those gates skipped.

Before recording any notable genuine blocker, gather repository and verification evidence and use at most one oracle consultation for that pass, batching related questions. The oracle is advisory and read-only: the active agent must independently verify any recommendation and retains all code, backlog, provider, commit, and integration mutation authority. Do not consult for routine choices or ordinary test failures; record accepted or rejected reasoning with the blocker evidence.

## Integration authority

Resolve integration before finishing, obeying repository `CLAUDE.md`/`AGENTS.md`/backlog configuration. Otherwise use pull-request flow when push access, branch protection, or remote ownership requires it; when ambiguous, use local merge. Local merge integrates completed verified work into local `main` and cleans up its temporary worktree without pushing. Pull-request flow pushes only this task branch and opens a PR with `gh`, without merging it; report the PR and recommend `/pr-babysit [reviewer]`. Never integrate unrelated work. Archive writable local backlog sources only when their repository convention requires it; use the provider adapter for archive operations.

## Completion and final report

An item is complete only when all selected tasks and acceptance criteria are implemented, verified, durably recorded, committed, and integrated. Source-only work is complete only when no open item remains in the whole resolved collection; explicit multi-item scope is complete only when every selected item is complete. If any work, blocker, failed write-back, or required archive remains, report `NEXT CONTEXT REQUIRED` and the exact next source/item/task. Otherwise report `BACKLOG COMPLETE AND ARCHIVED`.

Start the final response with exactly one of those status lines. Then reproduce the resolved source/order, selected item(s), completed tasks, implementation/state commits, verification results, durable provider markers, integration/archive result, exact next target if any, preserved unrelated changes or failures, and blockers or failed write-backs. Keep `$ARGUMENTS` unchanged in any continuation prompt.
