---
name: backlog-source-workflow
description: Resolve and operate on Markdown, Backlog.md, GitHub Issues, Linear, and other provider-backed work.
---

# Backlog Source Workflow

Keep the selected provider authoritative. The calling command supplies intent and mutation authority.

Resolve explicit sources first. Without one, use repository configuration or ask only when several sources are equally plausible. Match items by stable ID before exact title; do not fuzzy-match ambiguity away.

Use the provider's supported interface: preserve loose Markdown structure, use the `backlog` CLI or MCP for Backlog.md, `gh` for GitHub Issues, and an authenticated first-party integration for other providers. In a worktree, operate on Backlog.md state from the primary checkout.

Read enough collection state to understand status, dependencies, active claims, and prior progress. Prerequisites precede dependents. Prefer resumable work in the earliest ready wave. Treat ordinary implementation difficulty and failing tests as work, not blockers.

Use provider-native claims or concurrency controls when available. Refresh before consequential writes, record useful progress in the provider, and reread after writing. Never create a writable local shadow for remote work.

When refining an item, preserve product intent and stable IDs. Record a bounded next action, observable acceptance, affected surfaces, and genuine dependencies. Split only independently deliverable work; keep tightly coupled steps together.

When unblocking, investigate repository and provider evidence before asking the user. Preserve a blocker only for a real decision, external action, unavailable capability, or unresolved dependency. Record the answer or objective unblock condition where the next agent will find it.
