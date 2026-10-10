---
description: Implement one backlog item completely
argument-hint: <backlog-source|remote-ref> [item selector]
---

Use `backlog-source-workflow` to select one unclaimed item from `$ARGUMENTS`: resumable or review-pending work first, then the earliest dependency-ready item, then a blocked item whose recorded evidence can now resolve it. Acquire a provider-native claim when available, unless a supervising `worklease run` already holds it (`WORKLEASE_RUN_ID` is set). If nothing is eligible, report the exact claim, dependency, or blocker.

Read the selected item's full intent, acceptance criteria, history, and relevant code. Treat the entire item as the unit of completion and follow the `implement` workflow through implementation, validation, and required delivery. Identify every acceptance criterion and delivery obligation before editing, then keep working until each is satisfied with evidence. Checklist entries, implementation milestones, commits, and progress reports are not stopping points. Do not defer reachable item-scoped work to a follow-up or ask whether to continue.

After implementation and focused checks, perform at most one general review pass at a depth proportional to risk. Fix only concrete, item-scoped defects with an identifiable trigger and observable impact, then rerun the affected checks. Do not begin another general review unless a correction materially changed the design or behavior. Do not pursue speculative improvements, unrelated cleanup, or stylistic preferences.

Before finishing, check the result against the item's full intent, every acceptance criterion, and required delivery obligations. Continue working on any unmet requirement within your authority; ordinary implementation difficulty and failing checks are work to resolve, not blockers. Refresh repository and provider state. Integrate and commit only as authorized by the request and repository workflow. Record commits, verification, review outcome, remaining blocker, and the next resumable step in the authoritative provider, then reread it and release any claim you acquired.

Mark the item complete only when its acceptance criteria and required delivery obligations are satisfied. Stop incomplete only for a genuine blocker that cannot be resolved with available tools and authority, or an explicit user instruction to stop. Finish every reachable part first. If human input or permission is required, actively ask for the exact decision or action in the current session and resume after the answer; do not merely report the blocker and end. If the blocker remains unresolved, persist the evidence, exact missing input or external action, objective unblock condition, and next resumable step in the authoritative provider before releasing your claim.
