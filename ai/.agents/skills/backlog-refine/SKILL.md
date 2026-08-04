---
name: backlog-refine
description: Refine selected backlog items or whole backlog sources into implementation-ready work. Use when asked to clarify, decompose, or prepare work across Markdown, Backlog.md, GitHub Issues, Linear, or another supported provider.
---

# Backlog Refinement

Use `backlog-source-workflow` to resolve the requested source/items, dependencies, provider operations, and claims. The existing backlog is authoritative: preserve product intent, priorities, stable identifiers, completed work, and unrelated scope. Refine only the selected product scope; do not implement work, create unrelated follow-up items, or reprioritize the backlog.

## Refine in dependency order

Claim each selected item before changing it. Read its complete body, status, tasks, acceptance criteria, history, dependencies, neighboring items, related documentation, relevant implementation and call sites, and repository guidance. Read prerequisites before dependents. Independent items in the same ready wave may be explored in parallel, but the claim holder owns provider writes and reconciles shared interfaces.

For each item, record:

- intended outcome, in-scope work, and explicit non-goals
- affected interfaces and observable behavior
- every affected component and artifact: production code, callers, tests, fixtures, migrations, generated outputs, documentation, configuration, and validation baselines
- relevant edge cases, failures, recovery behavior, permissions, compatibility requirements, and migration rules
- the next actionable implementation step

Resolve routine ambiguity from evidence, repository conventions, and established reversible defaults. Escalate only a decision that materially changes product intent, ownership, security, cost, or irreversible behavior. Do not silently skip an ambiguous item: record its disposition and, when escalation is required, the evidence, exact owner decision, and objective unblock condition.

## Model readiness and dependencies

Model every unfinished prerequisite as an explicit dependency, including prerequisite implementation, credentials, access, approvals, environments, or externally owned changes. An item with a defined unfinished prerequisite is `ready after <item>`; do not mark it generically blocked.

Before marking an item ready, identify every required credential, account, device, permission, external mutation, protected-configuration change, payment, or owner decision. Remove the prerequisite when local fixtures, simulations, contract tests, or configuration checks prove the same outcome. Otherwise record:

- the exact unavailable or unauthorized capability
- why it is required
- the named owner or authorized actor where known
- the objective condition that unblocks it

Verify the selected dependency graph is acyclic after every split, consolidation, or dependency change. A ready item may depend only on available tools, accessible environments, declared completed prerequisites, and explicitly authorized capabilities. Never knowingly mark work ready when credentials, verification infrastructure, ownership decisions, or required external coordination remain unavailable.

## Make work autonomously executable

Preserve stable task IDs and checked tasks. Prefer an item-local checklist:

```markdown
### Implementation tasks
- [ ] T1 — one coherent, verifiable outcome
- [ ] T2 — the next coherent, verifiable outcome
```

Keep inseparable implementation, integration, callers, fixtures or migrations, and tests in one task. Split only at independently useful behavioral or subsystem boundaries where each resulting item is independently schedulable and verifiable. Consolidate artificial layer- or file-based splits. Create separate provider items only when the result is independently deliverable, exposes real dependency order, or enables useful parallel work; persist parent and dependency relationships. Otherwise retain item-local tasks.

Map every acceptance criterion, including previously checked criteria, to one implementation task or deliverable. For every criterion, provide autonomous evidence:

1. an exact local command, deterministic inspection, or reproducible procedure;
2. the expected result; and
3. any required fixture, simulation, contract test, or configuration state.

Do not use code presence, future CI, or “should work” as evidence. Prefer local deterministic evidence over remote or manual verification whenever it proves the same behavior. Record failure behavior and recovery checks where relevant.

## Persist and verify

Persist the refined item in its authoritative provider, then reread it and its relationships. Before release, verify for every selected item:

- the specification is coherent, scoped, and implementation-ready;
- dependencies and ordering are correct and acyclic;
- each acceptance criterion is objective, executable, and mapped to a task or deliverable;
- all questions have a recorded resolution, explicit owner decision, or objective unblock condition;
- provider updates, stable identifiers, checked work, and dependency relationships persisted correctly; and
- a fresh implementation agent can identify the next action without chat context or unstated assumptions.

Release the claim after verifying the authoritative state. Commit local backlog changes when authorized by repository or user instructions; remote provider changes need no shadow file or empty commit.

## Report

Return a concise report containing:

- items refined;
- dependencies added or corrected;
- acceptance criteria made executable;
- items split or consolidated and why;
- external prerequisites or owner decisions still required;
- items that remain unsafe for autonomous execution; and
- resulting ready work in dependency order.
