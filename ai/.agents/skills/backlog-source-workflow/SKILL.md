---
name: backlog-source-workflow
description: Resolve and operate on bl, Markdown, GitHub Issues, Linear, and other provider-backed work.
---

# Backlog Source Workflow

Keep the selected provider authoritative. The calling command supplies intent and mutation authority.

Resolve explicit sources first. Without one, use repository configuration or ask only when several sources are equally plausible. Match items by stable ID before exact title; do not fuzzy-match ambiguity away.

Use the provider's supported interface: use the `bl` skill when the repository has a `backlog.yaml` (including GitHub, Linear, or other sources configured there), preserve loose Markdown structure, use `gh` for GitHub Issues, and an authenticated first-party integration for other providers.

Read enough collection state to understand status, dependencies, active claims, and prior progress. Prerequisites precede dependents. Prefer resumable work in the earliest ready wave. Treat ordinary implementation difficulty and failing tests as work, not blockers.

For `bl` sources, let `bl next --claim --start` select and claim as the `bl` skill describes. Otherwise, when repository instructions name a Worklease queue view for the source, let it select and claim instead of choosing yourself: `worklease queue next --view NAME --claim --start --session ID --json` (MCP `queue_next` with `claim` and `start`), adding `--item SOURCE:ITEM` for an explicitly requested item. The returned claim is the lock; any `transition.outcome` other than `applied` means status unchanged, not a lost claim. If it reports no ready work, fall back to your own selection only for review-pending or blocked items whose evidence can now resolve them, and claim that item with `worklease acquire` on the exact `resources` reported by `worklease queue query --view NAME --json`.

Otherwise use provider-native claims or concurrency controls when available. When `WORKLEASE_RUN_ID` is set, a supervising `worklease run` already holds, renews, and on exit releases the Worklease claim for the handed-off item: do not acquire, heartbeat, or release it, use the inherited session for `worklease verify`, and before exiting write `{"outcome":"done|blocked|review|failed","summary":"..."}` to `$WORKLEASE_RUN_RESULT`. Refresh before consequential writes, record useful progress in the provider, and reread after writing. Never create a writable local shadow for remote work.

When refining an item, preserve product intent and stable IDs. Record a bounded next action, observable acceptance, affected surfaces, and genuine dependencies. Split only independently deliverable work; keep tightly coupled steps together.

When unblocking, investigate repository and provider evidence before asking the user. Preserve a blocker only for a real decision, external action, unavailable capability, or unresolved dependency. Record the answer or objective unblock condition where the next agent will find it.
