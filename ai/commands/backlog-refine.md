---
description: Refine backlog items into implementation-ready work for a lesser coding agent, then commit
argument-hint: <backlog-source|remote-refs> [item-ids|titles|ranges]
---

Refine the backlog items in `$ARGUMENTS` into implementation-ready work for a lesser coding agent, then commit changes.

Your goal is to make every refined item's specification 100% ready for development and give it an honest execution status: available now, ready after a named prerequisite, or blocked only by a genuinely external or unresolved prerequisite. Resolve the item's own open questions during refinement instead of handing them off. Investigate the repository, backlog, issue, product, and design context, decide each open question, and record the decision with its supporting evidence and rationale. Only escalate a question you genuinely cannot resolve — one that depends on information outside all available context and cannot be settled by a defensible default.

Treat `$ARGUMENTS` as the exact collection source and/or item selectors to refine: a loose Markdown backlog file, a whole Backlog.md project directory, a Linear project or issue set, a GitHub Issues repository/project/query, an item ID, title, range, or description. Do not refine unrelated backlog.

Apply the `backlog-source-workflow` skill as the shared source-resolution and provider-dispatch contract. Load its provider-neutral contract first, then one matching provider heading for each resolved provider kind, preserving the explicit source order when sources use unrelated provider kinds. It normalizes `Source`, `SchedulingScope`, `ItemState`, and optional `ReviewGroup`, resolves explicit sources and selectors left-to-right before deriving at most one unambiguous repository source, preserves source/selector order, and progressively loads only those selected headings. Treat `review-group:` only as provider scope metadata when the selected provider supports it and the caller explicitly supplies it; never infer a `ReviewGroup` from source-only scope, labels, adjacency, or selector shape. The skill's default review boundary is exactly one implementation item; this command's refinement authority, mutation rules, and commit requirements override the skill where they are more specific.

Keep collection scope separate from item selection. Source-only scope means the entire resolved collection, including every item in a whole Backlog.md project; it does not mean “choose the first item.” Item IDs, titles, ranges, and descriptions narrow the immediately preceding collection source, with exact ID taking precedence over title, then description. Preserve explicit source order across unrelated sources. After dependency readiness is established, preserve explicit selector order within each preceding source; when selectors span sources, source order remains authoritative across unrelated sources. For source-only collections, provider priority/ordinal/order ranks items only within each source and never reorders sources or explicit selections. Validate explicit sources left-to-right. A missing explicit local source path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported; otherwise an explicit source remains unresolved and refinement must not fall back to another unrelated or derived source. Missing implementation-reference paths in a selected item or non-backlog `$ARGUMENTS` hint are discovery hints, not source presence gates; carry them into the triage below rather than stopping.

## Backlog storage policy

Derive storage and mutation behavior per resolved collection source from repository context:

- A loose Markdown backlog file named in `$ARGUMENTS` is a writable source; edit it directly and preserve its established style.
- A whole Backlog.md project directory is a writable collection source. Discover and mutate project/task fields through the supported `backlog` CLI or MCP operations; do not edit task files directly when a provider-native operation exists.
- Every remote item is provider-owned and remote-only for refinement: never make a local Markdown backlog/spec/planning file writable as a mirror or create one for it. Use only a temporary read-only snapshot outside authoritative storage when provider-native refinement needs working context.

Provider operations stay narrow: use first-party Linear tooling for Linear; use `gh` for GitHub Issues; and preserve each provider's authorization boundaries. Remote item specifications and durable state may be mutated only through the selected provider's native operations. Remote writes are limited to the exact resolved items and the refined content authorized by `$ARGUMENTS`; do not change workflow status, create or delete remote items, or touch items outside that scope. If an integration is unavailable or unauthenticated, report the exact limitation.

Moving or renaming an existing local backlog file into the repository's archive location per repository convention is an edit to an existing source, not creation. When in doubt, do not create files; write only to an explicitly writable source.

## Remote backlog sources

Remote backlog references are discovery inputs, not moving text to refine in place. Durable item specifications and state remain provider-owned; temporary snapshots, handoff notes, command-local notes, and temporary files outside the worktree are read-only context, never authoritative storage. Invoking this command with a remote reference authorizes updating only the exact resolved items' content through that provider's first-party flow; it does not authorize workflow-status changes, creating or deleting remote items, or touching items outside `$ARGUMENTS`.

Before refining:

1. Resolve each remote collection or item reference with the provider-native integration: Linear MCP/tooling for Linear, `gh` for GitHub Issues, and the supported `backlog` CLI/MCP for Backlog.md projects. Establish the exact selected item identities and source/selector order. If a required integration is unavailable or unauthenticated, stop and report that exact limitation.
2. Before fetching or pinning selected item specification content, creating a working copy or read-only snapshot, or beginning any refinement work, preflight each selected item's exact provider-native specification content-update operation authorized by `$ARGUMENTS`. Use only a provider-native capability, authorization, scope, or non-mutating dry-run check for that exact item and content field; the preflight MUST NOT execute the update or mutate provider state. Do not use it to test or broaden authority to status changes, comments, creation, deletion, or other items.
3. If an item's exact content-update operation is unavailable, unauthenticated, unsupported, or scope-invalid, stop that item's remote flow before any working-copy, snapshot, or refinement edit, report the item unresolved and the exact limitation, and do not describe it as refined. Process another selected item only after its own exact preflight succeeds.
4. Fetch the selected collection or exact remote items in the source and selector order implied by `$ARGUMENTS`. A source-only invocation includes the entire resolved collection; selectors narrow it while preserving their explicit order after dependency readiness.
5. If provider-native refinement needs a working copy, use a temporary read-only snapshot outside authoritative storage (outside the worktree unless the provider requires a transient command-local location). Never treat a snapshot, handoff note, or local Markdown file as the remote item's writable source.
6. Refine the selected remote item through the provider-native operation and retain its receipt/version. Report any failed write and do not describe that item as refined.
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
   - **External or still unresolved:** record the evidence that no repository-owned item, generator, move, convention, or defensible item-local creation resolves it, then state the exact outside prerequisite and unblock condition.
4. If ownership is not explicit, settle it from product boundaries and repository patterns. Assign directly necessary item-local creation to the current item; reuse or create an earlier independently verifiable prerequisite for a shared artifact. Do not invent a source file merely to satisfy a stale or speculative path.

Only the final, evidence-backed external or unresolved case is a blocker. A known unfinished repository prerequisite is dependency-gated rather than ambiguous; a planned item-local file or generated artifact is implementation work, not a reason to stop refinement.

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
   - an explicit execution status in the source's existing vocabulary: available to begin only when no incomplete prerequisite prevents a start; ready after a named item when the specification is complete but that repository-owned prerequisite is unfinished; blocked only for a genuinely external or unresolved prerequisite
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
7. Resolve every open question and eliminate unknown blockers before assigning execution status. "Available to begin" means a lesser coding agent can start and complete the item without asking product, design, or architecture questions; without waiting for a prerequisite; without discovering unknown dependencies; and without relying on unresolved assumptions. "Ready after `<item>`" means the item is fully specified and becomes available as soon as that named predecessor satisfies its recorded artifact or interface contract; it is not a blocked or ambiguous item.
   - Actively investigate to answer each open question: read the surrounding backlog, the repository code and conventions, the linked issue, and any product or design context. Prefer an answer that is already explicit in that context.
   - Apply the subagent budget above: delegate only a bounded, independent investigation whose result can be checked against the repository; otherwise investigate directly.
   - When no explicit answer exists but a defensible choice can be made, decide it yourself using the repository's established patterns and the item's product intent as the default. Record the decision, the evidence or pattern it follows, and a one-line rationale so the implementer inherits a settled choice, not a question.
   - Collect consequential architecture or product questions that are hard to reverse or shape multiple downstream items, then use the invocation's single oracle consultation to evaluate them together. Record its input alongside your rationale; do not consult once per item or question.
   - When an open question implies prerequisite work, first look for related work that already owns it. Reuse and order after that item when found; otherwise split an earlier ready item with concrete acceptance criteria. Record the prerequisite ID and artifact or interface contract, and mark the dependent item ready after it rather than duplicating work or calling the dependency an unresolved blocker.
   - Escalate only a question you genuinely cannot resolve: one whose answer or prerequisite lives outside all available context (backlog, repo, issue, product, design), is not owned by identifiable related work, and cannot be settled by a defensible default without risking wrong or irreversible product behavior. For such a question, mark the affected item blocked/unavailable and state the exact missing decision or external prerequisite needed; do not fabricate an answer.
   - Do not describe any item with unresolved blockers, open product questions, unknown dependencies, ambiguous acceptance criteria, or latent assumptions as implementation-ready. A dependency-gated item may be implementation-ready only when its named predecessor and required output are exact; do not describe it as available to begin until that dependency is complete.

After editing:

- Verify the refined backlog still covers every item from `$ARGUMENTS`.
- Perform a final readiness check for each refined item before committing: confirm every open question and missing implementation reference was resolved and recorded, and that every item marked available to begin or ready after a named prerequisite has evidence or rationale for scope, reference disposition, dependencies, decisions, assumptions, acceptance criteria, and verification.
- Confirm task sizing as part of the final readiness check: each explicit task is a bounded, independently verifiable outcome; coupled code/callsite/test work is bundled; oversized behaviors are split into named ordered tasks; and all acceptance criteria are covered.
- Expect every item's specification to reach implementation-ready, either available now or explicitly ordered after a fully defined repository prerequisite. If a question survived only because it could not be resolved from any available context, list each such question in the output, identify the affected backlog item(s), state the exact missing decision or external prerequisite, and confirm those item(s) were left blocked/unavailable rather than implementation-ready. Do not leave a question unresolved or mark a missing path blocked for any other reason.
- Run only formatting or validation that applies to the edited backlog files.
- Commit any local backlog changes with a concise message; when only remote items changed, state that there is nothing to commit.
