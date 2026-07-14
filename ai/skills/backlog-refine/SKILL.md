---
name: backlog-refine
description: Refine selected backlog items or entire backlog sources into implementation-ready work. Use whenever a user asks to refine, clarify, decompose, or make a backlog ready for implementation across loose Markdown, Backlog.md, Linear, GitHub Issues, or another supported provider.
---

# Backlog Refinement

Refine exactly the requested sources/items for a lesser coding agent, then commit local changes. A source-only request selects the whole resolved collection. Resolve each open question from repository, backlog, issue, product, and design evidence; record the decision, evidence, and rationale instead of handing uncertainty to implementation.

Apply `backlog-source-workflow` for source resolution, provider dispatch, dependency scheduling, claims, and durable writes. Read its provider-neutral contract, then only the matching provider heading for each resolved kind. This skill may write only:

- refined specification content
- in normal mode, its claim lifecycle and matching `refined:`/`refinement: complete` checkpoint
- a verified human-required blocked state under the protocol below

It never creates `ReviewGroup` state or authorizes other workflow mutations.

## Scope and readiness

Keep collection sources separate from item selectors. IDs, titles, ranges, or descriptions narrow the immediately preceding source; preserve explicit source order and use exact ID, then exact title, then exact description precedence. Never replace an unresolved explicit source with an unrelated or repository-derived source; only the shared contract's single unambiguous adjacent-path substitution is allowed.

Build the complete dependency graph before work. Refine prerequisites before dependents in topological waves. Report readiness as:

- `available`: fully specified and no incomplete prerequisite prevents starting
- `ready after <item>`: fully specified but waiting on that defined repository prerequisite and its exact artifact/interface contract
- `blocked`: only provider-authored blockers, missing/cyclic dependency diagnostics, or an evidence-backed external/human decision satisfying the escalation protocol

An incomplete defined prerequisite is dependency-gated, never blocked. Its dependent enters a later refinement wave only after the prerequisite's specification write and durable `refinement: complete` checkpoint are discoverable.

## `mode:spec-only`

Parse the exact token before source resolution and preserve it in reported arguments. In this mode:

- edit only specification-bearing content for the selected items
- compute readiness for the report, but preserve all existing textual readiness/status fields and provider workflow state verbatim
- do not mutate claims, dependencies, priority, labels, assignees, comments, progress/review markers, completion, archive state, membership, or local shadows
- use only an operation that can update specification content without workflow state; otherwise report the capability limitation
- use one mutating session with no item workers or coordination claims; optional evidence gathering must remain read-only

Do not infer this mode from a directory source. Normal mode uses the shared contract's claims and durable refinement checkpoint but gains no additional workflow authority.

## Orchestration

For one selected item, work in the active agent and follow the same claim-before-context/edit rules. For multiple items:

1. Discover the selected collection and dependency targets; normalize terminal, blocker, refinement, and claim state; detect missing edges/cycles; compute waves.
2. Select only the next dependency-ready wave, excluding terminal, blocked, already refined, and actively claimed items plus their gated dependents.
3. Before snapshots, delegation, or edits, preflight the exact content update and, in normal mode, the claim, refinement-checkpoint, and possible blocker operations. Stop an item whose required provider operation or canonical claim resource is unavailable.
4. Narrow concurrent work around shared implementation surfaces. Acquire the strongest contract-supported claim for each item/source and revalidate dependencies. Report coordination-only work as `LOCAL COORDINATION (UNFENCED)`.
5. Dispatch one bounded batch of independent item proposals. Workers return evidence/proposals only; they never mutate providers, commit, manage claims, or decide cross-item contracts.
6. As claim holder, heartbeat, verify worker evidence, reconcile shared decisions, and perform authoritative writes in source/item order through the selected fenced or coordination-only path. Persist specification plus refinement checkpoint and refresh state; release item claims after each barrier and retain a source claim through the final wave or durable stop. Stop dependents on stale ownership, conflicts, ambiguous writes, missing checkpoints, or failed releases.

Use provider-owned state as authoritative. Never create a local mirror of remote work, directly edit Backlog.md task files, bypass guarded normal-mode writes, treat assignment/comment/status as a claim, or describe same-host coordination as cross-host/provider fencing. Commit only local source refinements; remote-only work has no shadow commit.

## Make each item implementation-ready

Each implementation task must be one coherent, independently verifiable behavioral outcome a lesser agent can implement, test, record, and commit in one bounded pass. Bundle inseparable production code, callsites, migrations/fixtures, and tests. Split independently useful behaviors or separate subsystems; never split by file, layer, test-writing, or checklist trivia. Map every acceptance criterion to tasks and every task to acceptance criteria.

Write implementation tasks under a `### Implementation tasks` heading as direct Markdown task-list entries with stable IDs, for example `- [ ] T1 — Add the parser`. Keep acceptance criteria in their own section and map them to these tasks; do not use arbitrary acceptance-criteria checkboxes as the implementation schedule. Preserve existing checked tasks and stable IDs when refining an item, and never reset `[x]` to `[ ]` without explicit evidence that the task was reopened.

For each item, preserve product intent while adding only implementation-relevant context:

- outcome-focused tasks with stable names and ordering
- target files/components/APIs/data, classifying each path as existing, new, generated by a named producer, or supplied by a named prerequisite
- explicit scope boundaries and non-goals
- dependencies and exact artifact/interface contracts
- edge states, migrations, permissions, failure modes, and task-specific verification
- acceptance criteria mapped to tasks
- readiness under the rules above
- an implementation snapshot: goal, target area, resolved decisions/assumptions with evidence, dispositions of open questions and missing references, known validation, pending verification, and next action

Add the least-confident assumption, a non-obvious risk, or one explicitly out-of-scope idea only when it helps implementation. Remove ambiguity, duplication, stale assumptions, and needless solution prescription.

## Missing references

A missing implementation path is evidence to investigate, not a blocker. Search the exact path, history, nearby locations, callsites, related items, generators, and repository conventions, then record one disposition:

- moved/renamed: replace it only when the match is unambiguous
- generated: name its input, producer/command, commit policy, and generation/use verification
- prerequisite output: name the owning item and artifact/interface; report `ready after <item>` while incomplete
- created here: mark it new, define its responsibility/integration, and verify creation/use
- external/unresolved: record why no repository-owned move, generator, item, convention, or safe item-local creation applies, then use the escalation test

When ownership is implicit, decide from product boundaries and existing patterns. Put directly necessary local work in the item; create/reuse an earlier independently verifiable prerequisite for shared work.

## Human escalation

Escalate only when a consequential decision/input must come from a human because it is absent from all available context and any default risks wrong or hard-to-reverse product behavior. Technical difficulty, missing paths, ordinary failures, unavailable commands, and incomplete repository prerequisites do not qualify.

Before escalating:

1. Exhaust relevant backlog, repository, issue, product, design, ownership, history, callsite, and targeted-check evidence.
2. Resolve routine/reversible choices with an established pattern or defensible default; record why.
3. Use bounded independent evidence gathering where it can reduce uncertainty.
4. Batch all remaining consequential questions into the invocation's single oracle consultation, including evidence, attempted resolutions, defaults, reversibility risk, and proposed unblock condition. Verify the advice against primary evidence.

In normal mode, persist the provider-authorized blocked state and `blocked:` evidence before final specification mutation or handoff. Evidence names the exact decision/input, investigation and oracle result, failed defaults, responsible role when known, and objective unblock condition. Refresh the item and require scheduling to normalize it as blocked; failed or ignored writes are durable-state failures, not successful escalation. This authority cannot set any other status. In `mode:spec-only`, report the same recommendation/evidence without mutating state.

## Delegation budget

Use at most four subagents per invocation: up to three `executor`/`explore` workers total plus one batched `oracle`. Delegate only materially independent items/subsystems, in one batch, from the current wave. Keep graph construction, claims, shared decisions, readiness, authoritative edits, and synthesis in the active agent. Verify all worker evidence before mutation.

## Completion gate

Before committing, verify every selected item is covered; every open question and missing reference has a recorded disposition; tasks are bounded outcomes; acceptance, dependencies, decisions, assumptions, and verification are sufficient for a lesser agent; and readiness is honest. Confirm normal-mode claim/write/checkpoint/release receipts or `mode:spec-only` workflow-state preservation. Run only applicable formatting/validation. Commit scoped local changes concisely; when only remote items changed, report that there is nothing local to commit.
