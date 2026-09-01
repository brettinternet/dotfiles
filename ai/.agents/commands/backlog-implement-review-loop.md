---
description: Implement and review one backlog item until complete
argument-hint: <backlog-source|remote-ref> [item selector]
---

Use `backlog-source-workflow` to select one unclaimed item from `$ARGUMENTS`: resumable or review-pending work first, then the earliest dependency-ready item, then a blocked item whose recorded evidence can now resolve it. Acquire a provider-native claim when available. If nothing is eligible, report the exact claim, dependency, or blocker.

Treat the selected item as the completion unit. Read its full intent, acceptance criteria, history, and relevant code. Implement the complete behavior, update required callers and artifacts, exercise the changed path, and run focused checks. Checklist entries are progress, not stopping points.

Review the resulting diff proportionately. Trace changed behavior through affected callers and report only defects with a concrete location, trigger, and observable impact. Fix valid item-scoped findings and rerun the relevant checks.

Use an isolated worktree when it protects existing work or repository policy requires it. Use an executor only for substantial disjoint implementation and a verifier when the item is materially risky or repository policy requires independent acceptance. The claim holder owns provider writes and integration.

Before finishing, refresh repository and provider state. Integrate and commit only as authorized by the request and repository workflow. Record commits, verification, review outcome, remaining blocker, and the next resumable step in the authoritative provider, then reread it and release the claim.

Complete the item only when its acceptance criteria and required delivery obligations are satisfied. Otherwise finish every reachable part and persist the exact external input or decision still required.
