---
description: Continuously review filtered PRs and post comments or approvals
argument-hint: '[linear-project] [gh-search-qualifiers...]'
---

Continuously review open PRs matching the optional Linear project and `gh search prs` qualifiers in `$ARGUMENTS`. Treat an argument containing a GitHub search qualifier such as `author:octocat`, `updated:>=2026-01-01`, or `repo:owner/name` as a qualifier rather than a Linear project. With no `author:` qualifier, match PRs by any author. This command authorizes review comments and approvals on matching PRs. Never edit code, push, merge, close, or request changes.

Keep per-repository state in `/tmp/pr-review-loop-state.json` containing each reviewed PR's authored commit subjects. Preserve other repositories' entries. Ignore merge commits and main-sync commits so rebases do not trigger another review.

Every 15 minutes:

1. Discover matching non-draft PRs. Pass all GitHub search qualifiers through to `gh search prs`. If a Linear project was supplied but unavailable, fall back to all PRs matching those qualifiers.
2. Skip PRs with no authored commits since the saved baseline. Do not post again on an unchanged PR already approved by the authenticated user.
3. Read the current diff scope, linked intent, surrounding affected code, affected callers, and all existing review discussion. Establish the actual operating context from PR and repository evidence: trust boundaries, data sensitivity, expected inputs and scale, rollout or migration assumptions, and failure and recovery paths. Keep prior concerns in a private ledger and never post the same underlying concern again.
4. Review only changes since the baseline on repeat passes. Judge whether the changed code is safe to ship in that operating context, spending scrutiny according to credible impact and blast radius rather than hypothetical uses. A finding requires a changed `path:line`, a concrete trigger, and observable breakage. Drop speculation, style, pre-existing problems, cleanup suggestions, and hardening for environments the code does not serve.
5. Choose `APPROVE` only when the reviewed change is safe to ship for the established context, no new finding exists, and no prior material concern remains. Choose `COMMENT` when a new finding clears the bar, or `WAIT` when only a prior concern remains unresolved. `WAIT` posts nothing.
6. For `COMMENT`, attach each finding to a changed line when possible and use one sentence naming trigger and breakage plus one direct question. For `APPROVE`, approve with no body. Apply `user-voice` to posted text.
7. Update the saved authored-commit baseline and print a Markdown progress table on every pass with one row per PR and columns for repository, linked PR number and title, author, action (`APPROVE`, `COMMENT`, `WAIT`, or `SKIP`), and concise status. Print the table headers even when no PRs match.

Use `gh` for every GitHub operation. A reviewer or `pr-watcher` may help with genuinely substantial review or change detection, but the loop owns scope, deduplication, and posting.

Stop when interrupted or after eight hours without a new candidate, authored commit, review, comment, thread change, or CI transition. Unchanged polling and rebases do not reset the idle timer.
