---
description: Refine selected backlog items or an entire backlog source into implementation-ready work, then commit
argument-hint: <backlog-source|remote-refs> [mode:spec-only] [item-ids|titles|ranges]
---

Refine the backlog items in `$ARGUMENTS` into implementation-ready work for a lesser coding agent, then commit changes. A source-only invocation covers the entire resolved collection; use `mode:spec-only` when the invocation must edit specification content without changing provider workflow state.

Your goal is to make every refined item's specification 100% ready for development and give it an honest execution status—or, in `mode:spec-only`, compute an honest status recommendation for reporting without writing it: available now, ready after a named prerequisite, or blocked only when the human-escalation protocol below proves a human decision or external input is required. Resolve the item's own open questions during refinement instead of handing them off. Investigate the repository, backlog, issue, product, and design context, decide each open question, and record the decision with its supporting evidence and rationale. Only escalate a question you genuinely cannot resolve after exhausting safe self-unblocking strategies and the single batched oracle consultation.

Treat `$ARGUMENTS` as the exact collection source and/or item selectors to refine: a loose Markdown backlog file, a whole Backlog.md project directory, a Linear project or issue set, a GitHub Issues repository/project/query, an item ID, title, range, or description. Do not refine unrelated backlog.

Apply `backlog-source-workflow` as the shared source-resolution, provider-dispatch, and claim-authority contract. Read its provider-neutral contract first, then one matching provider heading per resolved provider kind in source order. Use `Source`, `SchedulingScope`, `ItemState`, and `WorkClaim` plus discovery, dependency-wave selection, claim/heartbeat/release, reads, authorized specification updates, durable refinement checkpoints, and authorized blocked-state operations. This command may persist only refined specification content, its normal-mode `refined:` checkpoint and claim lifecycle, and the human-required blocker state below; it does not create `ReviewGroup` state.

Keep collection scope separate from item selection. Source-only scope means the entire resolved collection, including every item in a whole Backlog.md project; it does not mean “choose the first item.” Item IDs, titles, ranges, and descriptions narrow the immediately preceding collection source, with exact ID taking precedence over title, then description. Preserve explicit source order across unrelated sources. Build the complete dependency graph before assigning work, then traverse prerequisites before dependents in topological waves. Explicit selector order remains the tie-break within a wave; provider priority/ordinal/order ranks source-only items only within one wave and source, and never reorders sources or dependency edges. Validate explicit sources left-to-right. A missing explicit local source path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported; otherwise an explicit source remains unresolved and refinement must not fall back to another unrelated or derived source. Missing implementation-reference paths in a selected item or non-backlog `$ARGUMENTS` hint are discovery hints, not source presence gates; carry them into the triage below rather than stopping.

## `mode:spec-only`

Parse the exact `mode:spec-only` token before source and selector resolution. It is a command mode, not a source or item selector, and must be preserved in the invocation's reported arguments.

When `mode:spec-only` is active:

- A source-only argument still selects the entire resolved collection, including every task in a whole Backlog.md project directory. Item IDs, titles, ranges, and descriptions still narrow that collection.
- Edit only specification-bearing content for the exact selected items: descriptions, implementation tasks, acceptance criteria, implementation snapshots, decisions, assumptions, missing-reference dispositions, and next implementation actions in the source's established structure.
- Compute and report `available`, `ready after <item>`, or `blocked` as a readiness recommendation, but preserve any existing textual execution-status or readiness field verbatim. Do not add, remove, or rewrite that field, and do not write the provider's workflow status or state.
- Do not mutate provider workflow status, dependency relations, priority, labels, assignee, review or progress markers, completion, archive state, or item membership. Do not create or delete items, comments, or local shadow files.
- Preflight and use only the provider-authorized specification-content update operation, or the established direct-edit convention when the selected source is loose Markdown and no operation-specific tool exists. If the provider cannot update specification content without also changing workflow state, report the capability limitation and do not edit.
- This mode intentionally does not acquire provider-native or local coordination claims. Use one mutating session, do not dispatch item-level refinement workers, and retain only optional read-only evidence gathering. If safe completion requires cross-session exclusion, report that `mode:spec-only` cannot provide it rather than weakening the mode.

Without `mode:spec-only`, this command may mutate specification content, persist its matching durable `refined:` checkpoint, use the bounded claim lifecycle, and make only the provider-authorized human-required blocked transition defined below. It has no authority for any other workflow-state mutation. Do not infer specification-only mode from a directory source.

## Dependency-wave orchestration and claims

For a source-only invocation or multiple selected items, the active agent is the coordinator rather than one item worker:

1. Discover the entire selected collection plus dependency targets, normalize terminal/blocker/refinement/claim state, detect missing edges and cycles, and compute topological waves before assigning any item. An incomplete prerequisite opens its dependent's refinement wave only after its specification write and durable `refinement: complete` checkpoint are discoverable; release alone never opens the wave or makes the dependent implementation-ready.
2. Take only the next dependency-ready wave. Exclude terminal items, valid blockers, completed refinements, and unexpired item/source claims. An actively claimed prerequisite keeps every unfinished dependent out of later waves. If all scoped work is done, blocked, or held behind active claims, schedule no worker and report structured reasons and expiries.
3. Narrow the wave to items without shared implementation coordination surfaces. Select the strongest available guarantee for each resource: fenced `item-claim`, fenced `source-claim`, then `local-coordination`. Generate unique claim/worker-attempt IDs and acquire each `refine:<item-id>:<provider-version>` item resource, or acquire one source resource where the provider requires source serialization. Unsupported fencing automatically falls back to local coordination; pass `--coordination-only` to `backlog-claim acquire` and label that work `LOCAL COORDINATION (UNFENCED)`. Revalidate dependencies after acquisition and confirm each receipt's guarantee. Resolve ambiguous results by exact claim ID; never substitute a dependent.
4. Dispatch claimed item partitions together in one bounded batch. Each `executor` returns an item-scoped proposal/evidence only; workers do not mutate provider state, commit, decide cross-item contracts, or manage claims. Batch related same-subsystem items instead of creating workers for trivial entries.
5. The active agent is the holder: it observes workers, heartbeats by claim ID/token/current revision, reconciles decisions, checks evidence, and writes in source/item order through the selected claim mode. Fenced writes use the provider's guarded path. Coordination-only writes require an immediate lease/provider-state pre-check and post-check around each direct first-party mutation. Persist each specification plus `refined:` checkpoint and refresh `refinement: complete`. Release item claims after each barrier; retain a source claim through all selected waves and release only after the final barrier or durable stop.

One selected item stays in the active agent but follows the same claim-before-read/edit and selected mutation-mode rules. A coherent stop after a subtask/specification checkpoint releases the claim while preserving resumable `in-progress` state. An unexpected stop is recovered only after lease expiry and atomic reclaim; never steal an active claim, use an ordinary status/assignee/comment/branch/handoff as a lock, or describe local coordination as provider-side/cross-host fencing.

## Backlog storage policy

Derive storage and mutation behavior per resolved collection source from repository context:

- A loose Markdown backlog file named in `$ARGUMENTS` is a writable source. Outside `mode:spec-only`, acquire its fenced source claim and write only through `backlog-claim replace-file`; preserve its established style. In `mode:spec-only`, the existing single-mutator direct-edit rule remains.
- A whole Backlog.md project directory is a writable collection source. Discover through supported `backlog` CLI/MCP reads. Outside `mode:spec-only`, claim each item locally and project `@<assignee>` for visibility. Use fenced `backlog-claim exec ... -- backlog ...` mutations when the CLI is available; otherwise default to `local-coordination` and bracket authorized MCP mutations with lease/provider pre/post checks. Never edit task files directly. In `mode:spec-only`, use only specification-bearing provider operations and leave workflow state unchanged.
- Every remote item is provider-owned and remote-only for refinement: never create a local Markdown mirror. GitHub normal-mode writes run through guarded `gh`. Linear and other unfenced providers default to canonical `local-coordination` item leases and direct first-party writes with lease/provider pre/post checks; report `LOCAL COORDINATION (UNFENCED)`.

Provider operations stay narrow and preserve authorization boundaries. The local claim database contains leases only; provider specifications, progress, review, status, and completion remain authoritative in their source. In `mode:spec-only`, do not use provider operations for claims, status, progress, review, comments, dependencies, or other workflow-state changes.

Moving or renaming an existing local backlog file into the repository's archive location per repository convention is an edit to an existing source, not creation. When in doubt, do not create files; write only to an explicitly writable source.

## Remote backlog sources

Remote references authorize updating only exact resolved item content and, outside `mode:spec-only`, its matching `refined:` checkpoint, bounded claim lifecycle, and human-required blocked transition through the selected claim mode. Provider state remains authoritative; `local-coordination` excludes cooperating same-user agents on this host only, while snapshots and handoffs are read-only context. No other workflow mutation, item creation/deletion, or out-of-scope write is authorized.

Before refining:

1. Resolve each remote collection or item reference with the provider-native integration: Linear first-party tooling for reads, `gh` for GitHub Issues, and supported `backlog` CLI/MCP reads for Backlog.md projects. Establish exact identities and the complete dependency graph in source/selector order. If a required integration is unavailable or unauthenticated, stop and report that limitation.
2. Before fetching/pinning specification content, snapshots, delegation, or editing, preflight the exact content update. Outside `mode:spec-only`, also preflight the strongest available claim path plus the durable `refined:` checkpoint and possible human-blocker operations. Prefer native or helper fencing; automatically derive `local-coordination` when provider mutations cannot be fenced. Preflight is non-mutating.
3. Stop that item's flow before snapshot/delegation/edit only when a required provider operation is unavailable/unauthenticated/scope-invalid or no canonical local coordination lease can be derived. Cross-host exclusion is not required for the weaker default. Never downgrade to an assignee/comment/status claim or overstate local coordination as fencing. Continue only with another independent item in the same dependency-ready wave when the current item is truly capability `none`.
4. Fetch the complete selected collection and dependency targets. Use `selectWave(..., REFINE)` to compute prerequisite-first waves. A source-only invocation includes the entire resolved collection; selectors narrow mutation scope without hiding dependency state.
5. Outside `mode:spec-only`, acquire current-wave fenced or coordination-only item claims, or one source claim where required, before snapshots/workers. On item conflict, refresh and remove that item plus gated dependents; on source conflict, schedule nothing in that source. In `mode:spec-only`, use the single-mutator rule.
6. If provider-native refinement needs a working copy, use a temporary read-only snapshot outside authoritative storage. Never treat a snapshot, handoff note, or local Markdown file as the remote item's writable source.
7. Investigate and prepare item-scoped proposals under the orchestration rules above. The active agent settles all shared decisions. If and only if the human-escalation protocol concludes that human input is required, persist and verify the provider-native blocked state and marker before the final specification write.
8. Outside `mode:spec-only`, heartbeat/revalidate and write the specification plus `refined:` checkpoint through the selected fenced path or coordination-only pre/post-check sequence, then refresh `refinement: complete`; release item claims per barrier and a source claim after all selected waves. In `mode:spec-only`, write only specification content and verify its provider version. Missing completion, stale ownership, assignee conflict, file/provider conflict, failed/ambiguous write, or failed release stops dependents.
9. Commit refinements made to writable local sources with only task-related changes; remote-only provider changes have no local shadow commit.

If a remote item changes later, refresh it before refining again and use a fresh read-only snapshot when needed. Loose Markdown and Backlog.md projects remain first-class inputs: preserve Markdown style and, outside `mode:spec-only`, use the selected fenced or coordination-only provider mutation path rather than direct source/task-file edits.

## Missing implementation references

A file or directory referenced by an item may be an existing path, a stale path, a generated artifact, an output of related work, or something the item must create. Its absence alone is never a blocker. For every missing implementation reference in a selected item or non-backlog `$ARGUMENTS` hint, triage it before assigning readiness:

1. Search for the exact path, then use repository history and nearby path-like locations to find moves or renames. Update the item to an existing path only when the replacement is unambiguous; record the evidence for the correction.
2. Inspect neighboring and linked backlog items, remote dependency relations, prerequisite tasks, repository conventions, and callsites to identify who owns the missing artifact and when it should exist. Do not assume the current item owns it merely because it names the path.
3. Classify the reference and update the item accordingly:
   - **Moved or renamed:** replace the stale reference with the resolved existing path.
   - **Generated artifact:** name the source input, producer or generating command, and whether the artifact is committed; direct implementation to the producer rather than asking for hand-written generated output, and make acceptance verify generation plus downstream use.
   - **Output of related work:** name the prerequisite item, its required artifact or interface contract, and the ordering. Reuse that work instead of duplicating creation in the current item; mark the current item ready after that prerequisite while it is incomplete.
   - **Created by this item:** label the path as a new file or directory to create, state the responsibility and integration points it must contain, and add acceptance criteria and verification for its creation and use. Keep the item available to begin when no other dependency prevents it.
   - **External or still unresolved:** record the evidence that no repository-owned item, generator, move, convention, or defensible item-local creation resolves it, then state the exact outside prerequisite and unblock condition. Treat it as blocked only if the human-escalation protocol below proves that human input is required.
4. If ownership is not explicit, settle it from product boundaries and repository patterns. Assign directly necessary item-local creation to the current item; reuse or create an earlier independently verifiable prerequisite for a shared artifact. Do not invent a source file merely to satisfy a stale or speculative path.

Only a final, evidence-backed external or unresolved case that satisfies the human-escalation protocol is a blocker. A known unfinished repository prerequisite is dependency-gated rather than ambiguous; a planned item-local file or generated artifact is implementation work, not a reason to stop refinement.

## Human escalation and early blocked state

Outside `mode:spec-only`, refinement owns an early blocked transition solely to prevent implementation from starting on an item that genuinely requires human input. A technical difficulty, uncertain implementation detail, missing path, ordinary failure, incomplete repository prerequisite, or unavailable command integration is not by itself a human-required ticket blocker.

Before escalating, make a serious self-unblocking attempt:

1. Exhaust the selected item's backlog, repository, issue, product, and design evidence; inspect related ownership, dependencies, history, conventions, callsites, and targeted checks relevant to the question.
2. Resolve reversible or routine choices with the repository's established pattern or a defensible default, recording the evidence and rationale. Turn repository-owned missing work into item-local scope or an exact named prerequisite rather than a blocker.
3. Spend the bounded delegation budget on materially independent evidence gathering when it can reduce uncertainty. Increase investigation effort instead of escalating merely because the first search or approach failed.
4. Collect all remaining consequential questions and use the invocation's one oracle consultation as a final, batched challenge to the proposed escalation. Give the oracle the evidence, attempted resolutions, candidate defaults, reversibility risk, and proposed unblock condition. Independently check its recommendation against primary repository and provider evidence; the oracle cannot mutate state.
5. Escalate only when a specific decision or prerequisite must come from a human owner because it remains outside all available context and any default would risk wrong or hard-to-reverse product behavior. Name the human decision or external input precisely, not merely the uncertainty.

As soon as that conclusion is reached—and before final specification mutation, handoff, scheduling, or implementation begins for that item—persist the blocker through `backlog-source-workflow`. Use `writeState` for a provider-native blocked/unavailable workflow state. If the provider has no distinct native status, a `recordProgress` `blocked:` marker is sufficient only when the provider adapter explicitly normalizes that marker into blocked `ItemState`; never assume an ordinary comment affects scheduling. When status and evidence are distinct, write both the blocked state and the durable marker. The evidence must include the exact question or prerequisite, investigation and oracle evidence, why safe defaults failed, the responsible human role when known, and the objective unblock condition.

Refresh the provider-owned item after the write and verify that discovery/scheduling observes it as blocked and will skip it until the unblock condition changes. Retain the state and marker receipts. If either required write fails or refreshed normalized state is not blocked, stop that item's flow before specification mutation or implementation handoff, report the durable-state failure, and do not claim the ticket was blocked. Never use this authority to move an item to available, ready, in progress, complete, closed, archived, or any other state. In `mode:spec-only`, perform the same investigation and report the blocked recommendation and evidence, but do not write status, markers, comments, or any provider state.

## Delegation budget

- Default to direct investigation for one item or one tightly coupled subsystem. A source-only invocation or multiple selected items must use the dependency-wave coordinator above when the current wave has materially independent item partitions.
- Use at most four subagents for the entire invocation: at most three workers combined (`executor` for item-scoped refinement proposals, `explore` for substantial shared evidence gathering), plus at most one `oracle` consultation for all consequential unresolved tradeoffs.
- Dispatch eligible workers together in one batch. Partition by independent item/subsystem ownership, not by open question, missing path, callsite, or checklist entry. Do not replace finished workers after the total budget is spent.
- Keep dependency graph construction, claims/heartbeats/releases, cross-item contracts, readiness decisions, defaults, rationale, authoritative backlog edits, and final synthesis in the active agent. Independently verify worker evidence before mutation.
- If more work is eligible than the budget permits, process the highest-uncertainty independent partitions and handle the rest directly in the same wave. Never pull work from a later wave to fill capacity.

## Implementation task sizing

Refinement owns implementation-pass sizing. Each explicit task must be one coherent, independently verifiable behavioral outcome that a lesser agent can implement, test, record, and commit in one bounded pass.

- Bundle inseparable production code, required callsites, migrations or fixtures, and the tests that prove the same outcome into one task. Do not create separate tasks for files, layers, test-writing, formatting, or other steps that are not useful and verifiable on their own.
- Split a task when it contains multiple independently useful behaviors, crosses independent subsystems without a single atomic contract, or would require more repository context than its target files, required callsites, and targeted verification. Give every split task a stable, outcome-focused name, explicit acceptance coverage, expected verification, and ordering.
- Map every acceptance criterion to one or more explicit tasks and every task to acceptance criteria. Avoid both one giant item-level task and checklist trivia.
- The implementation commands treat these refined tasks as durable pass boundaries. Do not rely on an implementer to invent unnamed internal slices or reconstruct task boundaries from acceptance criteria.

For each backlog item:

1. Read the existing backlog text and nearby context before editing.
2. Preserve the product intent, but split vague or oversized work into small, independently executable tasks.
   Treat the sizing rules above as part of readiness: rewrite step-shaped or oversized checklists into coherent pass-sized tasks before marking the item available.
3. Add enough implementation context for a lesser coding agent to start without follow-up questions:
   - target files, components, commands, and existing patterns to inspect, with each path classified as existing to edit, new to create, generated by a named producer, or supplied by a named prerequisite
   - explicit non-goals and scope boundaries
   - dependencies and required ordering, reusing named related work or splitting new prerequisite work into earlier ready items when needed
   - edge cases, data states, migrations, permissions, and failure modes
   - acceptance criteria mapped to the explicit task or tasks that satisfy them, without requiring every acceptance criterion to become a separate task
   - the task-specific tests, checks, or manual QA expected, bundled with the behavior they prove
   - an explicit execution status—or, in `mode:spec-only`, a computed status recommendation for output only—in the source's existing vocabulary: available to begin only when no incomplete prerequisite prevents a start; ready after a named item when the specification is complete but that repository-owned prerequisite is unfinished; blocked only when the human-escalation protocol proves a human decision or external input is required. In `mode:spec-only`, preserve any existing textual status or readiness field verbatim and report discrepancies instead of editing it.
   - an item-scoped implementation snapshot in that item's existing structure:
     - goal / product intent
     - target file area, components, APIs, or data model involved, including the disposition of every missing reference
     - resolved decisions and assumptions, with the source evidence or rationale used for each
     - open questions the item raised and how each was resolved, with the evidence or default reasoning behind the decision
     - last known validation or evidence from the backlog text, if any
     - pending verification required before the item can be considered done
     - next recommended implementation action
4. Add a short item-specific add-on only when it helps the implementer:
   - least confident resolved assumption and the evidence supporting it
   - biggest non-obvious thing the implementer may be missing
   - one optional outstanding idea that is explicitly out of scope unless chosen
5. Remove ambiguity, duplicated tasks, stale assumptions, and solution-shaped instructions that are not required.
6. Keep tasks outcome-focused. Do not over-prescribe implementation unless the repo already has a clear matching pattern.
7. Resolve every open question and eliminate unknown blockers before assigning execution status, or before computing the status recommendation for output in `mode:spec-only`. "Available to begin" means a lesser coding agent can start and complete the item without asking product, design, or architecture questions; without waiting for a prerequisite; without discovering unknown dependencies; and without relying on unresolved assumptions. "Ready after `<item>`" means the item is fully specified and becomes available as soon as that named predecessor satisfies its recorded artifact or interface contract; it is not a blocked or ambiguous item.
   - Actively investigate to answer each open question: read the surrounding backlog, the repository code and conventions, the linked issue, and any product or design context. Prefer an answer that is already explicit in that context.
   - Apply the delegation budget above: delegate only a bounded, independent investigation whose result can be checked against the repository; otherwise investigate directly.
   - When no explicit answer exists but a defensible choice can be made, decide it yourself using the repository's established patterns and the item's product intent as the default. Record the decision, the evidence or pattern it follows, and a one-line rationale so the implementer inherits a settled choice, not a question.
   - Collect consequential architecture or product questions that are hard to reverse or shape multiple downstream items, then use the invocation's single oracle consultation to evaluate them together. Record its input alongside your rationale; do not consult once per item or question.
   - When an open question implies prerequisite work, first look for related work that already owns it. Reuse and order after that item when found; otherwise split an earlier ready item with concrete acceptance criteria. Record the prerequisite ID and artifact or interface contract, and mark the dependent item ready after it rather than duplicating work or calling the dependency an unresolved blocker.
   - Escalate only under the human-escalation protocol above: the answer or prerequisite lives outside all available context (backlog, repo, issue, product, design), is not owned by identifiable related work, and cannot be settled by a defensible default without risking wrong or irreversible product behavior. Persist and verify the scheduler-recognized blocked state before any final specification write or implementation handoff; in `mode:spec-only`, report the recommendation without mutating state. State the exact missing human decision or external prerequisite and objective unblock condition; do not fabricate an answer.
   - Do not describe any item with unresolved blockers, open product questions, unknown dependencies, ambiguous acceptance criteria, or latent assumptions as implementation-ready. A dependency-gated item may be implementation-ready only when its named predecessor and required output are exact; do not describe it as available to begin until that dependency is complete.

After editing:

- Verify the refined backlog still covers every item from `$ARGUMENTS`.
- Perform a final readiness check for each refined item before committing: confirm every open question and missing implementation reference was resolved and recorded, and that every item marked available to begin or ready after a named prerequisite has evidence or rationale for scope, reference disposition, dependencies, decisions, assumptions, acceptance criteria, and verification.
- Confirm task sizing as part of the final readiness check: each explicit task is a bounded, independently verifiable outcome; coupled code/callsite/test work is bundled; oversized behaviors are split into named ordered tasks; and all acceptance criteria are covered.
- Expect every item's specification to reach implementation-ready, either available now or explicitly ordered after a fully defined repository prerequisite. If a question survived only because it requires human input under the escalation protocol, list it in the output, identify the affected backlog item(s), state the exact missing decision or external prerequisite and unblock condition, summarize the self-unblocking and oracle evidence, and confirm those item(s) were left blocked/unavailable rather than implementation-ready. Do not leave a question unresolved or mark a missing path, technical difficulty, or ordinary failure blocked for any other reason.
- Outside `mode:spec-only`, verify every escalated item has provider receipts for its blocked workflow state and durable evidence marker where distinct, and refresh it to confirm normalized `ItemState` is blocked before reporting or handing off. A failed write, a marker the scheduler ignores, or an unverified normalized state is a durable-state failure, not a successful escalation.
- Outside `mode:spec-only`, verify item/source claim receipts, every fenced or coordination-only specification and `refined:` provider receipt, coordination pre/post receipts where applicable, refreshed `refinement: complete`, and final releases. If all roots are blocked, done, or actively claimed, confirm no worker was scheduled and report them rather than selecting dependents.
- Run only formatting or validation that applies to the edited backlog files.
- Commit any local backlog changes with a concise message; when only remote items changed, state that there is nothing to commit.
- In `mode:spec-only`, verify that provider workflow status, dependency relations, priority, labels, assignee, review/progress markers, completion, archive state, and existing textual execution-status/readiness fields are unchanged; commit only specification-content changes.
