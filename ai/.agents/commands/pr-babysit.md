---
description: Keep selected PRs green and address feedback until ready to merge
argument-hint: '[pr-number] [reviewer]'
---

Babysit one PR, or every open PR authored by the authenticated user when no number is supplied. An optional nonnumeric argument names the reviewer. Reject ambiguous arguments.

This command authorizes comments, reviewer requests, item-scoped fixes, commits, and pushes to each selected PR's existing head branch. Never merge, approve on another person's behalf, dismiss reviews, request changes, force-push, or touch another branch.

## Select safely

Resolve the repository and PR with `gh`. Retain the PR's source repository, head branch, and head SHA. Before every edit or push, require the PR to remain open and its source ref and expected head SHA to remain unchanged. Push explicitly to that source repository and branch.

For one PR, use the current checkout only when it is clean and exactly at the PR head. Otherwise use an isolated worktree. In batch mode, create one isolated worktree and one worker per PR; never share a checkout between PRs. Preserve any dirty or conflicted worktree for the user rather than discarding it.

## Clear CI and feedback

Loop over CI and unresolved review threads together:

- Inspect every gating check. Reproduce relevant failures locally, fix their source, run the repository's focused validation, commit, and push.
- Verify every review finding against current code. Apply the smallest valid fix and behavioral coverage when warranted. Reply briefly when a finding is stale or incorrect. Resolve a thread only after its fix lands or the discussion establishes it as resolved.
- After each push, refresh the expected head SHA and recheck CI and feedback. Stop rather than overwrite external changes.
- Apply `user-voice` to every GitHub message. Use `pr-watcher` for bounded waits when available; otherwise wait at least five minutes for CI and fifteen minutes for human review.

Do not weaken tests, suppress symptoms, make unrelated changes, or argue repeatedly. When a valid finding depends on a product or architecture decision, ask the user with the evidence and viable choices.

## Reviewer and finish

Once current feedback is clear and CI has no known failure, request the named reviewer if supplied and confirm the request landed. Continue processing their feedback until that exact reviewer approves the current head. If no reviewer was supplied, finish when feedback is clear and gating CI is green.

Stop a PR after eight hours without a head, CI, review, comment, or thread-state change. Report it as timed out, not ready. Finish with each PR's head SHA, CI and review state, unresolved findings, blocker, and worktree status. Say ready to merge only when every required condition is satisfied; do not merge.
