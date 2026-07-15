---
name: backlog-refine
description: Refine selected backlog items or whole backlog sources into implementation-ready work. Use when asked to clarify, decompose, or prepare work across Markdown, Backlog.md, GitHub Issues, Linear, or another supported provider.
---

# Backlog Refinement

Use `backlog-source-workflow` to resolve the requested source/items, dependencies, provider operations, and claims. Refine only the selected product scope; do not reprioritize unrelated work.

## Refine in dependency order

Read the full items, repository guidance, relevant code and history, related issues, and dependency contracts. Refine prerequisites before dependents. An item may be fully specified but `ready after <item>`; do not mark it blocked merely because its prerequisite is unfinished.

Claim each item before changing it. Independent items in the same ready wave may be explored in parallel, but the claim holder owns provider writes and reconciles shared interfaces.

## Make work implementable

Preserve product intent while adding only what an implementation agent needs:

- a clear outcome, scope, and non-goals
- stable, outcome-focused implementation tasks
- affected components, APIs, data, and whether referenced paths are existing or new
- explicit dependencies and artifact/interface contracts
- relevant edge cases, failures, migrations, permissions, and verification
- testable acceptance criteria mapped to the tasks
- resolved decisions and the next action

Prefer an item-local checklist:

```markdown
### Implementation tasks
- [ ] T1 — one coherent, verifiable outcome
- [ ] T2 — the next coherent outcome
```

Keep inseparable production code, call sites, fixtures/migrations, and tests in one task. Split at independently useful behavioral or subsystem boundaries, not by file, layer, or “write tests.” Preserve checked tasks and stable IDs.

Create separate provider items only when the result is independently deliverable, exposes real dependency order, or enables useful parallel work. Persist parent/dependency relationships, map every original acceptance criterion to an owner, and reread the resulting graph. If the provider cannot safely create or relate items, keep item-local tasks instead.

## Resolve uncertainty

Investigate missing paths and unclear references through search, history, call sites, generators, related items, and repository conventions. Record whether a path moved, is generated, belongs to a prerequisite, or will be created by this item.

Use an established or reversible default for routine engineering choices. Ask the user only when a consequential product or ownership decision is absent from available evidence and a guess risks materially wrong behavior. If that decision truly stops progress, record the evidence and objective unblock condition as a blocker; ordinary technical difficulty is not blocked.

## Finish

Before release, verify the selected items are coherent, the dependency graph is acyclic, tasks and acceptance criteria have clear ownership, open questions have a disposition, and a fresh implementation agent can proceed without chat context. Persist and verify the refined specification and readiness checkpoint, then release the claim. Commit local changes only when authorized by repository or user instructions; remote provider changes need no shadow file or empty commit.
