---
name: backlog-source-workflow
description: Resolve backlog sources and schedule provider-backed work through one normalized, dependency-aware interface. Use from authorized backlog commands and skills; do not invoke as a replacement for the caller's authority or scope.
disable-model-invocation: true
---

# Backlog Source Workflow

This skill supplies source resolution, discovery, dependency scheduling, provider operations, durable state, and archive mechanics. The caller retains scope and mutation authority and owns the actual refinement, implementation, review, or loop pass.

## Required loading

1. Read [`references/contract.md`](references/contract.md).
2. Resolve every provider kind while preserving explicit source order.
3. Read only the matching provider heading from [`references/local-providers.md`](references/local-providers.md) or [`references/remote-providers.md`](references/remote-providers.md).
4. Before acquiring, heartbeating, mutating under, or releasing a claim, also read [`references/claims.md`](references/claims.md). Read-only callers do not load it.

Apply the caller's authority to the normalized operations: `resolveSource`, `discover`, `selectNext`/`selectWave`, `readItem`, `claim`, `heartbeat`, `releaseClaim`, `writeState`, `recordProgress`, `reviewBoundary`, and `archive`.

Provider state remains authoritative. Never create a writable shadow, use assignment/status/comments as a claim, let provider order override dependencies or explicit source order, or describe local same-host coordination as provider-side/cross-host fencing.
