---
description: Keep selected PRs green and address feedback until ready to merge
argument-hint: '[pr-number | gh-search-qualifiers...] [--reviewer login]...'
---

Babysit either one PR identified by a single bare PR number in the current repository, or every open PR matching the supplied `gh search prs` qualifiers. With no selection arguments, match open PRs authored by the authenticated user. Pass search qualifiers through unchanged, including repository and organization scopes such as `repo:pdq/houston` and `org:pdq`. Repeat the optional `--reviewer LOGIN` argument to name one or more reviewers; reviewer arguments are not part of the search. Deduplicate repeated reviewer logins. Reject a PR number combined with qualifiers, a missing reviewer login, or otherwise ambiguous arguments.

This command authorizes comments, reviewer requests, item-scoped fixes, commits, and pushes to each selected PR's existing head branch. Never merge, approve on another person's behalf, dismiss reviews, request changes, force-push, or touch another branch.

## Select safely

Resolve a bare PR number in the current repository with `gh`. Otherwise discover matching PRs with `gh search prs`, requiring them to be open and passing every supplied qualifier through unchanged; searches may span repositories or an organization through qualifiers such as `repo:` and `org:`. Resolve each result in its own repository. Retain the PR's source repository, head branch, and head SHA. Before every edit or push, require the PR to remain open and its source ref and expected head SHA to remain unchanged. Push explicitly to that source repository and branch.

For a single selected PR, use the current checkout only when it belongs to that PR's repository, is clean, and is exactly at the PR head. Otherwise use an isolated worktree. For multiple selected PRs, run a bounded pool of at most four PR workers. Give each PR its own isolated worktree and worker; never share a checkout between PRs. Identify each worker by repository and PR number because searches may span repositories with overlapping PR numbers. Keep every edit, commit, push, expected-head update, and GitHub message scoped to that worker's PR. Before every edit or push, independently revalidate that the PR remains open and its source ref and expected head SHA are unchanged.

Each worker owns its PR's complete merge-conflict, CI, feedback, reviewer, and waiting loop until the PR finishes or stops. A blocked or waiting worker must not prevent the other active workers from progressing. Start up to four workers, then refill a slot as soon as its worker finishes or stops; do not wait for the whole active batch. The supervising agent schedules workers, handles escalations, and aggregates results, but does not enter an individual PR's polling loop. When it has no actionable scheduling, escalation, or synthesis work, use completion-driven or deferred continuation instead of polling or holding active execution. Preserve any dirty or conflicted worktree for the user rather than discarding it.

## Clear merge conflicts, CI, and feedback

Resolve merge conflicts before spending or requesting review attention: updating the PR head can clear approvals and make earlier review work stale. Check mergeability against the latest target branch before processing feedback, after target-branch changes, and before declaring the PR ready. When conflicted, merge the target branch into the PR head (never the PR head into the target), resolve only the conflicts, run focused validation, commit, and push. Do not rebase or force-push.

Once the PR is mergeable, loop over CI and unresolved review threads together:

- Inspect every gating check. Reproduce relevant failures locally, fix their source, run the repository's focused validation, commit, and push.
- Verify every review finding against current code. Apply the smallest valid fix and behavioral coverage when warranted. Reply briefly when a finding is stale or incorrect. Resolve a thread only after its fix lands or the discussion establishes it as resolved.
- After each push, refresh the expected head SHA and recheck mergeability, CI, and feedback. When the push fixes a review finding, re-request review from that review's author and confirm the request landed, especially when their latest review blocks merging. Stop rather than overwrite external changes.
- Apply `user-voice` to every GitHub message. Use `pr-watcher` for bounded waits when available; otherwise wait at least five minutes for CI and fifteen minutes for human review. Between polling passes, prefer an available deferred-continuation mechanism that releases active execution while preserving the session; in a standalone Pi session, use `wait_then_continue`. Otherwise use a bounded wait with an explicit deadline. Do not defer when the host cannot resume the same session or while running inside `/loop`.

Do not weaken tests, suppress symptoms, make unrelated changes, or argue repeatedly. When a valid finding depends on a product or architecture decision, ask the user with the evidence and viable choices.

## Reviewers and finish

Once the PR is mergeable, current feedback is clear, and CI has no known failure, request every named reviewer if supplied and confirm each request landed. Continue processing their feedback until every named reviewer approves the current head. If no reviewer was supplied, finish when feedback is clear and gating CI is green.

Stop a PR after eight hours without a head, CI, review, comment, or thread-state change. Report it as timed out, not ready. Sort final results by repository and ascending PR number, and include each PR's head SHA, CI and review state, unresolved findings, blocker, and worktree status. Say ready to merge only when every required condition is satisfied; do not merge.
