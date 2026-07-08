---
description: Refine backlog items into implementation-ready work for a lesser coding agent, then commit
argument-hint: <backlog-file|remote-refs> [item-ids|titles|ranges]
---

Refine the backlog items in `$ARGUMENTS` into implementation-ready work for a lesser coding agent, then commit changes.

Your goal is to make every refined item 100% ready for development: resolve the item's own open questions during refinement instead of handing them off. Investigate the repository, backlog, issue, product, and design context, decide each open question, and record the decision with its supporting evidence and rationale. Only escalate a question you genuinely cannot resolve — one that depends on information outside all available context and cannot be settled by a defensible default.

Treat `$ARGUMENTS` as the exact local backlog file, remote backlog references (such as Linear project identifiers, issue IDs, or issue URLs), item IDs, titles, or ranges to refine. Do not refine unrelated backlog.

Before reading or editing backlog content, identify explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, ranges, or remote backlog references as paths). Only verify paths that are actually listed in `$ARGUMENTS`; do not require or infer the presence of any other files. If a listed path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing listed path(s) plus nearby candidate(s). Do not refine or commit anything when stopped.

## Backlog storage policy

Before resolving backlog sources, derive `backlog_storage_mode` only from repository context. Because storage behavior is repo-constant, the mode must come from existing local backlog files, matching remote IDs in backlog markdown, or established backlog/spec snapshot conventions already present in the repo.

Derivation rules:

- use `local-existing-only` when `$ARGUMENTS` names an existing local markdown backlog file or a remote item has an unambiguous existing local markdown backlog entry
- use `remote-only` when the scoped sources are remote references and no existing local markdown backlog entry is found
- use `local-readwrite` only when existing repo context already shows a concrete convention for creating backlog/spec/planning markdown for remote items; otherwise do not synthesize files

`remote-only` never writes repo markdown, `local-existing-only` may edit existing local backlog markdown but must not create new backlog/spec/planning markdown, and `local-readwrite` may create or update repo-conventional backlog/spec/planning markdown.

## Remote backlog sources

Remote backlog references, such as Linear project identifiers, issue IDs, or issue URLs, are discovery inputs only. Do not refine against a moving remote source in place.

Before refining:

1. Resolve each remote reference using the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Fetch the exact remote items in the order implied by `$ARGUMENTS`.
3. Pin each remote item into an exact resolved backlog source according to `backlog_storage_mode` before any snapshot or refinement language. Never create or modify repo backlog/spec/planning markdown unless the policy explicitly permits it; when local repo writes are not permitted, keep the pinned remote text and refinement state in handoff notes, command-local notes, or a temporary file outside the worktree.
4. Refine the pinned source, not the moving remote text. Mirror the refined result back to the remote item only when an explicit first-party remote update flow is authorized; otherwise record whether the remote item is unchanged.
5. Commit local backlog refinements only where `backlog_storage_mode` permits writing and the changes are task-related; do not mix them with unrelated changes.

If the remote item changes later, refresh the pinned source first, then re-refine against the new pinned text.

Local repo markdown backlogs remain first-class inputs when `backlog_storage_mode` is `local-existing-only` or `local-readwrite`. When `$ARGUMENTS` names local markdown backlog files in those modes, use them directly after path validation and modify them following their existing style. In `remote-only`, treat local markdown as read-only context unless the user explicitly changes the policy.

For each backlog item:

1. Read the existing backlog text and nearby context before editing.
2. Preserve the product intent, but split vague or oversized work into small, independently executable tasks.
3. Add enough implementation context for a lesser coding agent to start without follow-up questions:
   - target files, components, commands, and existing patterns to inspect
   - explicit non-goals and scope boundaries
   - dependencies and required ordering, with prerequisite work split into earlier ready items when needed
   - edge cases, data states, migrations, permissions, and failure modes
   - acceptance criteria that can be verified without guessing
   - the specific tests, checks, or manual QA expected
   - a strict available-to-begin status: only items with all blockers, dependencies, decisions, risks, product questions, and assumptions resolved may be marked ready — resolve them during refinement so the item reaches this state rather than leaving it short
   - an item-scoped implementation snapshot in that item's existing structure:
     - goal / product intent
     - target file area, components, APIs, or data model involved
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
7. Resolve every open question and eliminate blockers before making an item available. "Available to begin" means a lesser coding agent can start and complete the item without asking product, design, or architecture questions; without discovering unknown dependencies; and without relying on unresolved assumptions.
   - Actively investigate to answer each open question: read the surrounding backlog, the repository code and conventions, the linked issue, and any product or design context. Prefer an answer that is already explicit in that context.
   - When no explicit answer exists but a defensible choice can be made, decide it yourself using the repository's established patterns and the item's product intent as the default. Record the decision, the evidence or pattern it follows, and a one-line rationale so the implementer inherits a settled choice, not a question.
   - Before recording a defensible-default decision on a consequential architecture or product question — one that is hard to reverse or that shapes multiple downstream items — consult the oracle agent for a second opinion on the tradeoff, and record its input alongside your rationale. This is proactive design input, separate from escalating a blocker.
   - When an open question implies prerequisite work, split that work into an earlier ready item with concrete acceptance criteria and order it ahead, so the dependent item still reaches ready.
   - Escalate only a question you genuinely cannot resolve: one whose answer lives outside all available context (backlog, repo, issue, product, design) and cannot be settled by a defensible default without risking wrong or irreversible product behavior. For such a question, mark the affected item blocked/unavailable and state the exact missing decision needed; do not fabricate an answer.
   - Do not describe any item with unresolved blockers, open product questions, unknown dependencies, ambiguous acceptance criteria, or latent assumptions as implementation-ready.

After editing:

- Verify the refined backlog still covers every item from `$ARGUMENTS`.
- Perform a final readiness check for each refined item before committing: confirm every open question the item raised was resolved and recorded, and that every item marked available to begin has resolved evidence or rationale for scope, dependencies, decisions, assumptions, acceptance criteria, and verification.
- Expect every item to reach implementation-ready. If a question survived only because it could not be resolved from any available context, list each such question in the output, identify the affected backlog item(s), state the exact missing decision, and confirm those item(s) were left blocked/unavailable rather than implementation-ready. Do not leave a question unresolved for any other reason.
- Run only formatting or validation that applies to the edited backlog files.
- Commit the changes with a concise message.
