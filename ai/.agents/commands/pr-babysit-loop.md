---
description: Keep selected PRs green and address feedback until ready to merge
argument-hint: '[pr-number | gh-search-qualifiers...] [--reviewer login[,login...]]...'
---

Repeat `pr-babysit` passes with `$ARGUMENTS` until every selected PR is `READY` or stopped. That command defines selection, authorization, worktrees and workers, conflict, CI, feedback, and reviewer handling, and each pass's report; follow it exactly on every pass, except that this command owns repetition. Drop finished and stopped PRs from later passes.

Use `pr-watcher` for bounded waits when available; otherwise wait at least five minutes while CI is pending and fifteen minutes while only human review is pending. Between passes, prefer an available deferred-continuation mechanism that releases active execution while preserving the session; in a standalone Pi session, use `wait_then_continue`. Otherwise use a bounded wait with an explicit deadline. Do not defer when the host cannot resume the same session or while running inside `/loop`.

Stop a PR after two hours of inactivity, not two hours since launch. A head change, external review or comment, or actual CI or thread-state transition resets that PR's idle timer. The agent's own comments and review requests and unchanged polling do not reset it. Report an idle timeout as paused awaiting review or CI (or name the actual blocker), not ready.

Persist each PR's `last_activity_at` (UTC) and last observed head, CI, review, comment, and thread state in `~/.local/state/pr-babysit-loop.json`, keyed by repository and PR number; preserve other PRs' entries. Initialize the timestamp when a PR is first observed only when no saved idle state exists. Save observed state after every pass, including the agent's own actions so they are not mistaken for external activity later. On resume or polling restart, compare against the saved state and retain the timestamp unless qualifying activity occurred; use the event time when available, not the restart time. Bound each wait by the remaining idle time. Serialize shared-state writes from workers to avoid lost updates.

Finish with the last pass's report. Say ready to merge only when every required condition is satisfied; do not merge.
