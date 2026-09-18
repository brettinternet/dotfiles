---
description: Implement one backlog item completely
argument-hint: <backlog-source|remote-ref> [item selector]
---

Use `backlog-source-workflow` to select one unclaimed item from `$ARGUMENTS`: resumable or review-pending work first, then the earliest dependency-ready item, then a blocked item whose recorded evidence can now resolve it. Acquire a provider-native claim when available. If nothing is eligible, report the exact claim, dependency, or blocker.

Read the selected item's full intent, acceptance criteria, history, and relevant code. Treat the item as the complete change request and follow the `implement` workflow to implement and validate it. Checklist entries are progress, not stopping points.

After implementation and focused checks, perform at most one general review pass at a depth proportional to risk. Fix only concrete, item-scoped defects with an identifiable trigger and observable impact, then rerun the affected checks. Do not begin another general review unless a correction materially changed the design or behavior. Do not pursue speculative improvements, unrelated cleanup, or stylistic preferences.

Before finishing, refresh repository and provider state. Integrate and commit only as authorized by the request and repository workflow. Record commits, verification, review outcome, remaining blocker, and the next resumable step in the authoritative provider, then reread it and release the claim.

Complete the item only when its acceptance criteria and required delivery obligations are satisfied. Otherwise finish every reachable part and persist the exact external input or decision still required.
