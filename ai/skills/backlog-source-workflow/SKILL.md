---
name: backlog-source-workflow
description: Resolve backlog sources and schedule provider-backed work through one normalized, dependency-aware interface. Apply whenever an authorized backlog command or skill reads or mutates a backlog source; do not invoke as a replacement for the caller's authority or scope.
user-invocable: false
---

# Backlog Source Workflow

This skill supplies source resolution, discovery, dependency scheduling, provider operations, durable state, and archive mechanics. The caller retains scope and mutation authority and owns the actual refinement, implementation, review, or loop pass.

Every authorized backlog entrypoint loads this skill before interpreting source or item content. This is an agent workflow contract, not a filesystem hook: a generic direct read of a file named `backlog.md` is not itself guaranteed to load the skill.

## Item-local task checklists

Implementation tasks belong inside the ticket/item and are not separate backlog units. When a caller refines or implements an item, use a canonical `### Implementation tasks` section with direct Markdown task-list entries in stable order:

```markdown
### Implementation tasks
- [ ] T1 — Add the parser
- [ ] T2 — Update callers
```

Use the stable task ID (`T1`, `T2`, and so on) when claiming, reporting, and recording progress. A checked box is durable item-local progress, not provider completion; callers must still persist the matching commit, verification, acceptance-criteria state, and provider workflow state through the selected provider operation. Preserve completed boxes and unknown item content, and never turn nested checklist entries into separately scheduled backlog items.

## Required loading

1. Read [`references/contract.md`](references/contract.md).
2. Resolve every provider kind while preserving explicit source order.
3. Read only the matching provider heading from [`references/local-providers.md`](references/local-providers.md) or [`references/remote-providers.md`](references/remote-providers.md).
4. Before acquiring, heartbeating, mutating under, or releasing a claim, also read [`references/claims.md`](references/claims.md). Read-only callers do not load it.

Apply the caller's authority to the normalized operations: `resolveSource`, `discover`, `selectNext`/`selectWave`, `readItem`, `claim`, `heartbeat`, `releaseClaim`, `writeState`, `recordProgress`, `reviewBoundary`, and `archive`.

Provider state remains authoritative. Never create a writable shadow, use assignment/status/comments as a claim, let provider order override dependencies or explicit source order, or describe local same-host coordination as provider-side/cross-host fencing.
