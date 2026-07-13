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

Treat every command as calling the same operations: `resolveSource`, `discover`, `selectNext`/`selectWave`, `readItem`, `claim`, `heartbeat`, `releaseClaim`, `writeState`, `recordProgress`, `reviewBoundary`, and `archive`. Pass the caller's authority and scope into every operation. Provider workflow state remains provider-owned; the selected provider section may use the repository's same-host `backlog-claim` service solely as the claim authority.

- `Source`: the resolved provider kind, locator, display name, and opaque provider metadata.
- `SchedulingScope`: the ordered source/item collection eligible for this invocation; source-only scope means the entire resolved collection for every resolved source.
- `ItemState`: one item and its durable provider status, dependencies, priority/order, refinement/review progress, and current `WorkClaim`.
- `WorkClaim`: a bounded ownership epoch with unique claim/worker IDs, session/agent identity, exact work key, coordination revision/time, heartbeat/expiry, and a fencing token required by every claimed mutation. It is either provider-native or an authorized same-host lease, never an assignee/status/comment substitute. Expired claims are resumable only through a fresh claim ID; active claims exclude every other attempt.
- `ReviewGroup` (optional): an explicitly requested provider-native milestone/epic/parent group. Parse a caller token as `review-group:<provider-native-selector>` and resolve it through the selected provider; the default review boundary remains exactly one implementation item.

Treat arguments as an ordered list. Preserve every explicit source in that order, including unrelated provider kinds; never let provider priority reorder sources. Resolve explicit sources before repository-derived detection. A supplied explicit source that fails never falls back to another or derived source. A missing explicit local path may use at most one clearly adjacent same-directory or moved/renamed-basename candidate, but the substitution and original path must be reported; ambiguity or no candidate is an explicit failure. Repository derivation is permitted only when no explicit source was supplied and exactly one candidate remains.

Build the complete dependency graph before scheduling. Dependency order is a hard gate for every provider: never select an item whose prerequisite is incomplete, missing, cyclic, or blocked. Refinement traverses topological waves and may advance only after each predecessor's specification write plus durable `refinement: complete` checkpoint is discoverable; release alone never opens the next wave. Implementation/review still requires terminal prerequisites.

Claims are the next hard gate. `selectNext`/`selectWave` exclude active item or source claims, prioritize unclaimed/expired-claim resumable work in the current wave, and return structured complete/blocked/active-claims state instead of reaching past an unavailable prerequisite. Atomically claim before delegation/isolation/edit, heartbeat while active, revalidate dependencies, fence every mutation by claim ID/token/revision, and checkpoint before release. Adapters declare `item-claim`, fenced `source-claim`, or `none`; fail closed on partial/racy support. This permits independent ready roots without allowing a dependent behind unfinished or claimed work.

Use provider-native reads and writes for task progress and completion. Claims use the authority selected by the provider section: provider-native fencing when available, otherwise the same-host `backlog-claim` helper only for Backlog.md CLI, GitHub CLI, and fenced loose-Markdown replacement. Remote provider state remains authoritative; the local lease database is coordination state only and never a writable backlog, progress, review, dependency, or completion shadow. Use `gh` for GitHub Issues, guarded Backlog.md CLI rather than direct project-file edits, and the provider's first-party integration for Linear. Linear and any write that cannot execute inside the selected fence declare claim capability `none`. Archive only through the selected provider's operation or established source convention when the caller authorized it.
