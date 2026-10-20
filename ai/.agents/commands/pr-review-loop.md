---
description: Continuously review filtered PRs and post comments or approvals
argument-hint: '[linear-project] [gh-search-qualifiers...] [-- review-instructions]'
---

Run a `pr-review` pass with `$ARGUMENTS` every 15 minutes. That command defines selection, authorization, the review standard, posting, the patch-ID review baseline, and each pass's progress table; follow it exactly on every pass, except that this command owns repetition.

Between passes, prefer an available deferred-continuation mechanism that releases active execution while preserving the session; in a standalone Pi session, use `wait_then_continue`. Otherwise use a bounded wait with an explicit deadline. Do not defer when the host cannot resume the same session or while running inside `/loop`.

Stop when interrupted or after eight hours of inactivity across the matching PRs, not eight hours since launch. A new candidate, authored commit, external review or comment, or actual thread-state or CI transition resets the idle timer. The agent's own reviews, comments, and review requests, unchanged polling, and rebases do not reset it.

Persist `last_activity_at` (UTC) and the last observed candidate, commit, review, comment, thread, and CI state in `~/.local/state/pr-review-loop.json`, with idle tracking keyed by the normalized selection scope, excluding review guidance after `--`. Initialize the timestamp on the first observation only when no saved idle state exists. Save observed state after every pass, including the agent's own actions so they are not mistaken for external activity later. On resume or polling restart, compare against the saved state and retain the timestamp unless qualifying activity occurred; use the event time when available, not the restart time. Bound each wait by the remaining idle time.
