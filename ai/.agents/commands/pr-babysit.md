---
description: Make one pass getting selected PRs green and through feedback, then exit
argument-hint: '[pr-number | gh-search-qualifiers...] [--reviewer login[,login...]]...'
---

Make one pass over either one PR identified by a single bare PR number in the current repository, or every open PR matching the supplied `gh search prs` qualifiers, then exit. A scheduler owns repetition; do all currently actionable work, but do not wait for CI or reviewers, poll, or schedule another pass. With no selection arguments, match open PRs authored by the authenticated user. Pass search qualifiers through unchanged, including repository and organization scopes such as `repo:organization/repo` and `org:organization`. Name reviewers with the optional, repeatable `--reviewer LOGIN[,LOGIN...]` argument; reviewer arguments are not part of the search. Deduplicate repeated reviewer logins. Reject a PR number combined with qualifiers, a missing reviewer login, or otherwise ambiguous arguments.

This command authorizes comments, reviewer requests, item-scoped fixes, commits, and pushes to each selected PR's existing head branch, and recording a linked PR phase on its backlog item. Never merge, approve on another person's behalf, dismiss reviews, request changes, force-push, or touch another branch.

## Select safely

Resolve a bare PR number in the current repository with `gh`. Otherwise discover matching PRs with `gh search prs`, requiring them to be open and passing every supplied qualifier through unchanged. Resolve each result in its own repository. Retain the PR's source repository, head branch, and head SHA. Before every edit or push, require the PR to remain open and its source ref and expected head SHA to remain unchanged. Push explicitly to that source repository and branch.

Skip a PR without starting a worker when it has nothing actionable: it is mergeable, no gating check has failed, no review thread awaits a fix or reply, and every named reviewer is approved or already requested on the current head.

For a single selected PR, use the current checkout only when it belongs to that PR's repository, is clean, and is exactly at the PR head. Otherwise use an isolated worktree. For multiple actionable PRs, run a bounded pool of at most four PR workers, each with its own isolated worktree; never share a checkout between PRs. Identify each worker by repository and PR number because searches may span repositories with overlapping PR numbers. Keep every edit, commit, push, expected-head update, and GitHub message scoped to that worker's PR. Refill a slot as soon as its worker finishes. Preserve any dirty or conflicted worktree for the user rather than discarding it, and reuse a clean one left by an earlier pass.

## Clear merge conflicts, CI, and feedback

Resolve merge conflicts first: updating the PR head can clear approvals and make earlier review work stale. When conflicted against the latest target branch, merge the target branch into the PR head (never the PR head into the target), resolve only the conflicts, run focused validation, commit, and push. Do not rebase or force-push.

Then handle CI and unresolved review threads together:

- Inspect every failed gating check. Reproduce relevant failures locally, fix their source, run the repository's focused validation, commit, and push. Leave pending checks to a later pass.
- Verify every review finding against current code. Apply the smallest valid fix and behavioral coverage when warranted. Reply briefly when a finding is stale or incorrect. Resolve a thread only after its fix lands or the discussion establishes it as resolved.
- After each push, refresh the expected head SHA. When the push fixes a review finding, re-request review from that review's author and confirm the request landed, especially when their latest review blocks merging. Stop rather than overwrite external changes.
- Apply `user-voice` to every GitHub message.

Do not weaken tests, suppress symptoms, make unrelated changes, or argue repeatedly. When a valid finding depends on a product or architecture decision, ask the user with the evidence and viable choices.

## Reviewers and report

Once the PR is mergeable, current feedback is clear, and CI has no known failure, request every named reviewer who has neither approved the current head nor a pending request, and confirm each request landed.

For each PR this pass pushed to, commented on, or requested review for, record a linked PR phase through `backlog-source-workflow`.

Report a Markdown table sorted by repository and ascending PR number with the head SHA, action taken this pass, CI and review state, unresolved findings, worktree status, and status: `READY` when mergeable, gating CI is green, feedback is clear, and every named reviewer approved the current head (or none was named); `WAITING` naming the pending CI or reviewer; or `BLOCKED` naming the blocker. Never merge.
