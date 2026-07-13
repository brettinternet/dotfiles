---
name: backlog-source-workflow
description: Resolve backlog sources and schedule provider-backed work through one normalized, dependency-aware interface. Use from backlog commands; do not invoke as a replacement for a command's authority or scope.
disable-model-invocation: true
---

# Backlog Source Workflow

Commands remain the authority and scope entrypoints. This skill supplies the shared source-resolution, provider-discovery, scheduling, durable-state, and archive protocol; it does not perform a command's implementation, review, or loop pass.

## Progressive loading (required)

1. Read [`references/contract.md`](references/contract.md) first. It is the only provider-neutral contract.
2. Resolve the provider kind before loading provider instructions.
3. Read exactly one selected provider section per resolved provider kind from either [`references/local-providers.md`](references/local-providers.md) or [`references/remote-providers.md`](references/remote-providers.md). Read the matching heading only (for example, `Loose Markdown`, `Backlog.md`, `Linear`, `GitHub Issues`, or `Future providers`); do not load unrelated provider sections. If explicit sources use unrelated provider kinds, load those selected headings in preserved source order.
4. Apply that section's discovery, mutation, durable-write, and archive rules through the contract. A future provider must add one section implementing the same contract; commands do not change.

## One normalized interface

Treat every command as calling the same operations: `resolveSource`, `discover`, `selectNext`, `readItem`, `writeState`, `recordProgress`, `reviewBoundary`, and `archive`. Pass the caller's authority and scope into every operation. A provider never grants authority merely because it can resolve an item, and a handoff or local note is never a substitute for provider-owned durable state.

- `Source`: the resolved provider kind, locator, display name, and opaque provider metadata.
- `SchedulingScope`: the ordered source/item collection eligible for this invocation; source-only scope means the entire resolved collection for every resolved source.
- `ItemState`: one implementation item and its durable provider state, dependencies, priority/order, and review status.
- `ReviewGroup` (optional): an explicitly requested provider-native milestone/epic/parent group. Parse a caller token as `review-group:<provider-native-selector>` and resolve it through the selected provider; the default review boundary remains exactly one implementation item.

Treat arguments as an ordered list. Preserve every explicit source in that order, including unrelated provider kinds; never let provider priority reorder sources. Resolve explicit sources before repository-derived detection. A supplied explicit source that fails never falls back to another or derived source. A missing explicit local path may use at most one clearly adjacent same-directory or moved/renamed-basename candidate, but the substitution and original path must be reported; ambiguity or no candidate is an explicit failure. Repository derivation is permitted only when no explicit source was supplied and exactly one candidate remains.

After dependency readiness has excluded blocked items, an explicit item selector's order wins and is never reordered by provider priority or ordinal. Resolve each selector with exact precedence: stable provider ID, then exact title, then exact description; an ambiguous match at the winning level is a diagnostic. Provider priority/ordinal/order applies only within a source-only collection (with source order still winning across sources). Detect and surface missing dependencies and dependency cycles as blocked state; never silently skip or reorder around them.

Use provider-native reads and writes, including task progress and completion markers. Remote providers are authoritative: any local snapshot/cache is read-only temporary context and is never a writable backlog, progress, review, dependency, or completion shadow. Use `gh` for GitHub Issues, Backlog.md CLI/MCP rather than direct project-file edits, and the provider's first-party integration for Linear. Loose Markdown may use direct edits only when the selected existing source convention provides no operation-specific tool. Archive only through the selected provider's operation or its established source convention, and only when the caller authorized it.
