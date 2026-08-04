---
name: backlog-unblock
description: Resolve human decisions, missing inputs, stale blockers, and decision-only backlog items. Use when asked to unblock work or persist answers across Markdown, Backlog.md, GitHub Issues, Linear, or another supported provider.
---

# Backlog Unblock

Use `backlog-source-workflow` to resolve the requested items, dependencies, provider operations, and claims. This skill may clarify specifications, resolve blocker records, restore the provider's existing ready state, or complete a decision-only item. It does not implement production work or close ordinary implementation items.

## Classify the stop

Refresh the item and investigate backlog context, dependencies, repository evidence, history, call sites, and provider discussion.

- A defined unfinished prerequisite is `ready after <item>`, not blocked.
- An active claim means wait, not blocked.
- Ordinary technical difficulty, a missing path, or a failing test is implementation work, not blocked.
- Clear stale, already-answered, or invalid blocker records when evidence resolves them.
- Preserve a blocker only for a consequential human decision/input, an external action, an explicit provider blocker, or an unresolved missing/cyclic dependency.

## Resolve decisions

Do not ask the user to repeat repository investigation. For each genuinely unresolved decision, state what it blocks, summarize the evidence, recommend a viable option, and offer a small set of materially different alternatives. Combine questions that share one decision.

After the answer, claim the affected selected item or explicit item bundle. Write the decision near the requirement it affects, including constraints and acceptance impact. Resolve only blocker records satisfied by that decision; preserve unrelated blockers. Complete a decision-only item only when the recorded answer satisfies its entire purpose and no implementation or external action remains.

If an external action still remains, record the responsible party when known and an objective unblock condition instead of repeatedly asking the same question.

## Finish

Reread the affected items and dependency graph. Confirm the decision is discoverable without chat context and that readiness changed no more broadly than justified. Verify the provider checkpoint, then release the claim. Do not create a local shadow for remote work or commit when only a remote provider changed.
