---
description: List backlog work in dependency order with readiness, review, and claim status
argument-hint: [backlog-source|remote-ref] [item selectors]
---

List open work for `$ARGUMENTS`. This command is read-only: do not acquire claims or change local or remote state.

Use `backlog-source-workflow` to resolve the source and selectors. Preserve explicit source order, never silently fall back from an unresolved explicit source, and derive a repository source only when exactly one is plausible.

Read the complete dependency graph and current Worklease claims. Show open implementation work, resumable progress, review-pending items and open implementation PRs, genuine blockers, and dependency-gated items. Order prerequisites before dependents; within the same ready wave prefer resumable or review work before new work.

For each item, report its source, stable ID and title, readiness or gating reason, active claim owner/expiry when present, and which other ready items can safely run in parallel. Treat only independent, unclaimed items in the same dependency-ready wave as parallel. If nothing is claimable, say whether the cause is completion, active claims, dependencies, or genuine blockers.
