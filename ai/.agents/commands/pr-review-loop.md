---
description: Continuously review PRs by an author and post comments or approvals
argument-hint: <github-author> [linear-project] [gh-search-qualifiers...]
---

Continuously review open PRs by `$1`, optionally scoped by a Linear project and additional `gh search prs` qualifiers. This command authorizes review comments and approvals on matching PRs. Never edit code, push, merge, close, or request changes.

Keep per-repository state in `/tmp/pr-review-loop-state.json` containing each reviewed PR's authored commit subjects. Preserve other repositories' entries. Ignore merge commits and main-sync commits so rebases do not trigger another review.

Every 15 minutes:

1. Discover matching non-draft PRs. If a Linear project was supplied but unavailable, fall back to all matching PRs by the author.
2. Skip PRs with no authored commits since the saved baseline. Do not post again on an unchanged PR already approved by the authenticated user.
3. Read the current diff scope, linked intent, surrounding affected code, and all existing review discussion. Keep prior concerns in a private ledger and never post the same underlying concern again.
4. Review only changes since the baseline on repeat passes. A finding requires a changed `path:line`, a concrete trigger, and observable breakage. Drop speculation, style, pre-existing problems, and cleanup suggestions.
5. Choose `APPROVE` when no new finding exists and no prior material concern remains, `COMMENT` when a new finding clears the bar, or `WAIT` when only a prior concern remains unresolved. `WAIT` posts nothing.
6. For `COMMENT`, attach each finding to a changed line when possible and use one sentence naming trigger and breakage plus one direct question. For `APPROVE`, approve with no body. Apply `user-voice` to posted text.
7. Update the saved authored-commit baseline and print one concise status line per PR.

Use `gh` for every GitHub operation. A reviewer or `pr-watcher` may help with genuinely substantial review or change detection, but the loop owns scope, deduplication, and posting.

Stop when interrupted or after eight hours without a new candidate, authored commit, review, comment, thread change, or CI transition. Unchanged polling and rebases do not reset the idle timer.
