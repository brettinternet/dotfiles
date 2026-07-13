---
description: Refine selected backlog items or an entire backlog source into implementation-ready work, then commit
argument-hint: <backlog-source|remote-refs> [mode:spec-only] [item-ids|titles|ranges]
---

Refine the backlog items in `$ARGUMENTS` into implementation-ready work for a lesser coding agent, then commit changes. A source-only invocation covers the entire resolved collection; use `mode:spec-only` when the invocation must edit specification content without changing provider workflow state.

Your goal is to make every refined item's specification 100% ready for development and give it an honest execution status—or, in `mode:spec-only`, compute an honest status recommendation for reporting without writing it: available now, ready after a named prerequisite, or blocked only when the human-escalation protocol below proves a human decision or external input is required. Resolve the item's own open questions during refinement instead of handing them off. Investigate the repository, backlog, issue, product, and design context, decide each open question, and record the decision with its supporting evidence and rationale. Only escalate a question you genuinely cannot resolve after exhausting safe self-unblocking strategies and the single batched oracle consultation.

Treat `$ARGUMENTS` as the exact collection source and/or item selectors to refine: a loose Markdown backlog file, a whole Backlog.md project directory, a Linear project or issue set, a GitHub Issues repository/project/query, an item ID, title, range, or description. Do not refine unrelated backlog.

Apply `backlog-source-workflow` as the shared source-resolution and provider-dispatch contract. Read its provider-neutral contract first, then one matching provider heading for each resolved provider kind in explicit source order. Use `Source`, `SchedulingScope`, and `ItemState` plus the provider's resolution, discovery, read, authorized specification-update, and authorized blocked-state operations. Preserve source and selector order and load only the selected provider headings. This command refines specifications and may persist only the human-required blocker state defined below; it does not resolve review boundaries or create `ReviewGroup` state.

Keep collection scope separate from item selection. Source-only scope means the entire resolved collection, including every item in a whole Backlog.md project; it does not mean “choose the first item.” Item IDs, titles, ranges, and descriptions narrow the immediately preceding collection source, with exact ID taking precedence over title, then description. Preserve explicit source order across unrelated sources. After dependency readiness is established, preserve explicit selector order within each preceding source; when selectors span sources, source order remains authoritative across unrelated sources. For source-only collections, provider priority/ordinal/order ranks items only within each source and never reorders sources or explicit selections. Validate explicit sources left-to-right. A missing explicit local source path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported; otherwise an explicit source remains unresolved and refinement must not fall back to another unrelated or derived source. Missing implementation-reference paths in a selected item or non-backlog `$ARGUMENTS` hint are discovery hints, not source presence gates; carry them into the triage below rather than stopping.

## `mode:spec-only`

Parse the exact `mode:spec-only` token before source and selector resolution. It is a command mode, not a source or item selector, and must be preserved in the invocation's reported arguments.

When `mode:spec-only` is active:

- A source-only argument still selects the entire resolved collection, including every task in a whole Backlog.md project directory. Item IDs, titles, ranges, and descriptions still narrow that collection.
- Edit only specification-bearing content for the exact selected items: descriptions, implementation tasks, acceptance criteria, implementation snapshots, decisions, assumptions, missing-reference dispositions, and next implementation actions in the source's established structure.
- Compute and report `available`, `ready after <item>`, or `blocked` as a readiness recommendation, but preserve any existing textual execution-status or readiness field verbatim. Do not add, remove, or rewrite that field, and do not write the provider's workflow status or state.
- Do not mutate provider workflow status, dependency relations, priority, labels, assignee, review or progress markers, completion, archive state, or item membership. Do not create or delete items, comments, or local shadow files.
- Preflight and use only the provider-authorized specification-content update operation, or the established direct-edit convention when the selected source is loose Markdown and no operation-specific tool exists. If the provider cannot update specification content without also changing workflow state, report the capability limitation and do not edit.

Without `mode:spec-only`, this command may mutate specification content and may make only the provider-authorized human-required blocked transition defined below. It has no authority for any other workflow-state mutation. Do not infer specification-only mode from a directory source.

## Backlog storage policy

Derive storage and mutation behavior per resolved collection source from repository context:

- A loose Markdown backlog file named in `$ARGUMENTS` is a writable source; edit it directly and preserve its established style.
- A whole Backlog.md project directory is a writable collection source. Discover and mutate project/task fields through the supported `backlog` CLI or MCP operations; do not edit task files directly when a provider-native operation exists. Outside `mode:spec-only`, a human-required escalation may use the provider-native blocked-state operation defined below. When `mode:spec-only` is active, restrict operations to specification-bearing fields and leave provider workflow state unchanged.
- Every remote item is provider-owned and remote-only for refinement: never make a local Markdown backlog/spec/planning file writable as a mirror or create one for it. Use only a temporary read-only snapshot outside authoritative storage when provider-native refinement needs working context.

Provider operations stay narrow: use first-party Linear tooling for Linear; use `gh` for GitHub Issues; and preserve each provider's authorization boundaries. Remote item specifications and durable state may be mutated only through the selected provider's native operations. Remote writes are limited to the exact resolved items, the refined content authorized by `$ARGUMENTS`, and—outside `mode:spec-only`—the human-required blocked transition defined below. Do not make any other workflow-status change, create or delete remote items, or touch items outside that scope. In `mode:spec-only`, do not use provider operations for status, progress, review, comments, dependency relations, or other state changes. If an integration is unavailable or unauthenticated, report the exact limitation.

Moving or renaming an existing local backlog file into the repository's archive location per repository convention is an edit to an existing source, not creation. When in doubt, do not create files; write only to an explicitly writable source.

## Remote backlog sources

Remote backlog references are discovery inputs, not moving text to refine in place. Durable item specifications and state remain provider-owned; temporary snapshots, handoff notes, command-local notes, and temporary files outside the worktree are read-only context, never authoritative storage. Invoking this command with a remote reference authorizes updating only the exact resolved items' content and—outside `mode:spec-only`—persisting the human-required blocked transition defined below through that provider's first-party flow. It does not authorize any other workflow-status change, creating or deleting remote items, or touching items outside `$ARGUMENTS`.

Before refining:

1. Resolve each remote collection or item reference with the provider-native integration: Linear MCP/tooling for Linear, `gh` for GitHub Issues, and the supported `backlog` CLI/MCP for Backlog.md projects. Establish the exact selected item identities and source/selector order. If a required integration is unavailable or unauthenticated, stop and report that exact limitation.
2. Before fetching or pinning selected item specification content, creating a working copy or read-only snapshot, or beginning any refinement work, preflight each selected item's exact provider-native specification-content update. Outside `mode:spec-only`, also preflight every operation a human-required escalation may need: the scheduler-recognized blocked workflow state and the durable `blocked:` progress marker when those are distinct provider operations. Use only provider-native capability, authorization, scope, or non-mutating dry-run checks for that exact item and field; preflight MUST NOT execute an update or mutate provider state. This preflight grants no authority for any other status, comment, creation, deletion, or item. In `mode:spec-only`, preflight only specification content and never probe or invoke a state mutation.
3. If an operation required by the current mode is unavailable, unauthenticated, unsupported, or scope-invalid, stop that item's remote flow before any working-copy, snapshot, or refinement edit, report the item unresolved and the exact limitation, and do not describe it as refined or durably blocked. Process another selected item only after all of its own required preflights succeed.
4. Fetch the selected collection or exact remote items in the source and selector order implied by `$ARGUMENTS`. A source-only invocation includes the entire resolved collection; selectors narrow it while preserving their explicit order after dependency readiness.
5. If provider-native refinement needs a working copy, use a temporary read-only snapshot outside authoritative storage (outside the worktree unless the provider requires a transient command-local location). Never treat a snapshot, handoff note, or local Markdown file as the remote item's writable source.
6. Investigate and refine the selected remote item in memory or its read-only snapshot. If and only if the human-escalation protocol below concludes that human input is required, persist and verify the provider-native blocked state and marker before writing specification changes or handing the item to any implementation agent. Then write the refined specification through the provider-native content operation. Retain every receipt/version; report any failed write, and do not describe the item as refined or durably blocked unless the corresponding write and verification succeeded.
7. Commit refinements made to writable local sources with only task-related changes; remote-only provider changes have no local shadow commit.

If a remote item changes later, refresh the provider-owned item before refining again and use a fresh read-only snapshot when needed. Loose local Markdown files and Backlog.md project directories remain first-class inputs: preserve Markdown's existing style, and use supported Backlog.md CLI/MCP operations rather than direct task-file edits when available. Local Markdown that is not a writable backlog source is read-only context.

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

## Subagent budget

- Default to direct investigation. One item, one subsystem, or an explicit implementation surface does not justify delegation.
- Delegate within this budget only when refinement has materially substantial, independent investigation branches; otherwise investigate directly.
- Use at most three subagents for the entire invocation: no more than two `explore` workers for materially substantial, independent investigation areas, plus at most one `oracle` consultation for consequential unresolved tradeoffs. This is a total budget, not a concurrency limit; do not replace finished agents with new ones.
- Batch related items and questions by subsystem. Do not create one agent per backlog item, open question, missing path, callsite, or evidence source.
- Keep readiness decisions, defaults, rationale, backlog edits, and final synthesis in the active agent. If more investigation is eligible than the budget permits, delegate the highest-uncertainty branches and perform the rest directly.

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
   - Apply the subagent budget above: delegate only a bounded, independent investigation whose result can be checked against the repository; otherwise investigate directly.
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
- Run only formatting or validation that applies to the edited backlog files.
- Commit any local backlog changes with a concise message; when only remote items changed, state that there is nothing to commit.
- In `mode:spec-only`, verify that provider workflow status, dependency relations, priority, labels, assignee, review/progress markers, completion, archive state, and existing textual execution-status/readiness fields are unchanged; commit only specification-content changes.
