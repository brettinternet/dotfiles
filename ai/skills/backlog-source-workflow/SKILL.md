---
name: backlog-source-workflow
description: Resolve backlog sources and schedule provider-backed work through one normalized, dependency-aware interface. Apply whenever an authorized backlog command or skill reads or mutates a backlog source; do not invoke as a replacement for the caller's authority or scope.
user-invocable: false
---

# Backlog Source Workflow

This skill supplies source resolution, discovery, dependency scheduling, provider operations, durable state, and archive mechanics. The caller retains scope and mutation authority and owns the actual refinement, implementation, review, or loop pass.

Every authorized backlog entrypoint loads this skill before interpreting source or item content. This is an agent workflow contract, not a filesystem hook: a generic direct read of a file named `backlog.md` is not itself guaranteed to load the skill.

## Item-local task checklists

Implementation tasks belong inside the ticket/item and are not separate backlog units. Provider-item decomposition is a distinct operation available only when the caller explicitly authorizes it. When a caller refines or implements an item, prefer a canonical `### Implementation tasks` section with direct Markdown task-list entries in stable order:

```markdown
### Implementation tasks
- [ ] T1 — Add the parser
- [ ] T2 — Update callers
```

Use the stable task ID (`T1`, `T2`, and so on) when claiming, reporting, and recording progress. A checked box is durable item-local progress, not provider completion; callers must still persist the matching commit, verification, acceptance-criteria state, and provider workflow state through the selected provider operation. Preserve completed boxes and unknown item content, and never turn nested checklist entries into separately scheduled backlog items.

The canonical checklist is a preferred representation, not a start-time gate. If it is absent or malformed but the item's scope is unambiguous, the caller may map an equivalent task list or derive the smallest bounded task from the item specification, then normalize the checklist when provider mutation is available. A formatting defect alone is never a `BLOCKED` or `WAIT` reason; stop only for genuine scope, dependency, authority, capability, or decision ambiguity.

## Required loading

1. Read [`worklease-workflow`](../worklease-workflow/SKILL.md) and its [`references/contract.md`](../worklease-workflow/references/contract.md) first; it is normative for graph construction, claim lifecycle, guarantee mapping, checkpoint ordering, and structured outcomes.
2. Read [`references/contract.md`](references/contract.md).
3. Resolve every provider kind while preserving explicit source order.
4. Read only the matching provider heading from [`references/local-providers.md`](references/local-providers.md) or [`references/remote-providers.md`](references/remote-providers.md).
5. When a resolved provider kind is Backlog.md, also load the [`backlog-md`](../backlog-md/SKILL.md) skill after the matching provider heading for its CLI/MCP and ticket-authoring conventions.
6. Before acquiring, heartbeating, mutating under, or releasing a claim, also read [`references/claims.md`](references/claims.md). Read-only callers do not load it.

Apply the caller's authority to the normalized operations: `resolveSource`, `discover`, `selectNext`/`selectWave`, `readItem`, `claim`, `heartbeat`, `releaseClaim`, `createItem`, `writeState`, `recordProgress`, `reviewBoundary`, and `archive`.

Provider state remains authoritative. Never create a writable shadow, use assignment/status/comments as a claim, let provider order override dependencies or explicit source order, or describe local same-host coordination as provider-side/cross-host fencing.
