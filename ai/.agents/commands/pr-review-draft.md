---
description: Draft a PR review without posting it
argument-hint: <pr-number|url>
---

Review PR `$ARGUMENTS` read-only. Do not edit code or post anything unless the user later authorizes the action from this review.

Use `gh` to read the PR, complete diff, linked issue when available, and existing comments, reviews, and threads. The issue supplies intent; every authored change remains reviewable. Inspect enough surrounding code and affected callers to trace behavior.

Keep a private ledger of concerns already raised by any reviewer. Do not draft them again, even if moved, outdated, answered, or incompletely fixed; report their current state only in chat.

Review proportionately for correctness, regressions, security, data integrity, concurrency, compatibility, performance at expected scale, and behavioral coverage. A finding must have all three:

1. a real changed `path:line`
2. a triggering input, state, or path
3. an observable breakage

Drop speculation, style preferences, pre-existing problems, duplicate concerns, and cleanup suggestions. A clean review is expected when no defect clears the bar. Keep at most four findings, highest impact first.

Report in chat:

```text
<two sentences describing the changed execution path>
State: <review and prior-concern state>
Action: <APPROVE, COMMENT, or WAIT>
```

Choose `APPROVE` when there are no new findings and no unresolved material concern, `COMMENT` when new findings clear the bar, and `WAIT` when only a prior material concern remains unresolved.

For `COMMENT`, draft each finding as:

```text
<path:line>
<one sentence naming the trigger and breakage>
<one direct question>
```

Apply `user-voice`, then `draft-in-editor` with slug `pr-review-<N>`. Do not create a draft for `APPROVE` or `WAIT`.

If the user later authorizes the reported action, reread current PR state first. Approve with no body for `APPROVE`; post the saved draft exactly for `COMMENT`, treating `path:line` as routing metadata and falling back to a top-level review when no changed line fits; post nothing for `WAIT`. Never request changes.
