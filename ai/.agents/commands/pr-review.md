---
description: Review filtered PRs once and post comments or approvals
argument-hint: '[linear-project] [gh-search-qualifiers...]'
---

Run one review pass over open PRs matching the optional Linear project and `gh search prs` qualifiers in `$ARGUMENTS`, then exit. A scheduler owns repetition; do not wait, poll, or schedule another pass. Treat an argument containing a GitHub search qualifier such as `author:octocat`, `updated:>=2026-01-01`, or `repo:owner/name` as a qualifier rather than a Linear project. With no `author:` qualifier, match PRs by any author. This command authorizes review comments and approvals on matching PRs. Never edit code, push, merge, close, or request changes.

Keep per-repository state in `~/.local/state/pr-review.json` containing each reviewed PR's authored commit subjects. Preserve other repositories' entries. Ignore merge commits and main-sync commits so rebases do not trigger another review.

1. Discover matching non-draft PRs. Pass all GitHub search qualifiers through to `gh search prs`. If a Linear project was supplied but unavailable, fall back to all PRs matching those qualifiers.
2. Skip PRs with no authored commits since the saved baseline. Do not post again on an unchanged PR already approved by the authenticated user.
3. Read the current diff scope, linked intent, surrounding affected code, affected callers, and all existing review discussion. Establish the actual operating context from PR and repository evidence: trust boundaries, data sensitivity, expected inputs and scale, rollout or migration assumptions, and failure and recovery paths. Existing review discussion, including your own earlier comments, is the ledger of prior concerns; never post the same underlying concern again.
4. When a baseline exists, review only changes since it. Judge whether the changed code is safe to ship in that operating context, spending scrutiny according to credible impact and blast radius rather than hypothetical uses. A finding requires a changed `path:line`, a concrete trigger, and observable breakage. Drop speculation, style, pre-existing problems, cleanup suggestions, and hardening for environments the code does not serve.
5. Choose `APPROVE` only when the reviewed change is safe to ship for the established context, no new finding exists, and no prior material concern remains. Choose `COMMENT` when a new finding clears the bar, or `WAIT` when only a prior concern remains unresolved. `WAIT` posts nothing.
6. For `COMMENT`, attach each finding to a changed line when possible and use one sentence naming trigger and breakage plus one direct question. For `APPROVE`, approve with no body. Apply `user-voice` to posted text.
7. Update the saved authored-commit baseline, then print a Markdown table with one row per PR and columns for repository, linked PR number and title, author, action (`APPROVE`, `COMMENT`, `WAIT`, or `SKIP`), and concise status. Print the table headers even when no PRs match.

Use `gh` for every GitHub operation. A reviewer may help with genuinely substantial review, but this pass owns scope, deduplication, and posting.
