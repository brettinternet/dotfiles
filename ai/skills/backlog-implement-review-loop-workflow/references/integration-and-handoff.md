# Integration and Handoff

## Verification

- Use the smallest behavioral check that proves the selected pass: focused tests, typecheck, lint, build, migration validation, browser QA, or a manual scenario.
- Re-run the focused check after every fix.
- Diagnose and repair in-scope failures before considering a blocker.
- Record unrelated failures separately with evidence; never claim project-wide health without project-wide checks.

## Commits

- Commit only task-related implementation, review fixes, or state changes.
- Keep implementation commits, review-fix commits, and marker-only commits distinguishable so a marker can name the exact reviewed code state.
- Use concise messages and preserve unrelated work.

## Integration

Resolve the repository's declared flow first:

- `local-merge`: merge completed verified work to local main, clean the temporary worktree, and do not push.
- `pull-request`: push only the task branch and open a PR against the declared/default base; do not force-push, merge the PR, or touch unrelated branches. Keep the pushed branch after worktree cleanup.

When no flow is declared, use a pull request for a protected/shared remote or when base push access is unavailable; otherwise default to local merge. An explicit invocation authorizes only this workflow's task branch and repository-declared integration.

## Completion and archive

A scoped item is complete only when all tasks and acceptance criteria are implemented, targeted verification passes, the exact final implementation state has a valid durable `status: complete; remaining: none` review marker, required commits exist, and integration is complete.

Use `BACKLOG COMPLETE AND ARCHIVED` only when every scoped item across every supplied source meets that condition, writable local backlogs are archived per convention, and each remote-only item has its durable completion marker plus a done/merged transition when the first-party tool supports it. Report an unsupported workflow transition; a failed durable marker write leaves the item incomplete.

Use `NEXT CONTEXT REQUIRED` whenever scoped work remains open, blocked, unreviewed, unintegrated, unarchived, or lacks required durable state.

## Handoff requirements

Use [the handoff template](../templates/handoff.md). Include facts another fresh agent can act on without prior chat:

- resolved sources and source-order map
- item/task or review batch processed
- completed state and exact next state
- authoritative local backlog entry or remote comment written, including status, completed task/commit, verification, exact next task/state, and remaining acceptance criteria
- implementation, review-fix, marker, and integration commits
- reviewed commit state and changed files
- criteria/tasks verified and exact command results
- remaining ordered work, blockers, risks, product decisions, and unrelated failures
- oracle recommendation and whether it was accepted
- exact next invocation

Handoff must be reconstructible from the authoritative backlog entry or remote comments. Never use it to replace a failed or unavailable durable state write.

Do not report a phase boundary as completion. The status line must reflect the entire supplied scope.
