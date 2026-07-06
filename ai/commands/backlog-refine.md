---
description: Refine backlog items into implementation-ready work for a lesser coding agent, then commit
argument-hint: <backlog-file|remote-refs> [item-ids|titles|ranges]
---

Refine the backlog items in `$ARGUMENTS` into implementation-ready work for a lesser coding agent, then commit changes.

Treat `$ARGUMENTS` as the exact local backlog file, remote backlog references (such as Linear project identifiers, issue IDs, or issue URLs), item IDs, titles, or ranges to refine. Do not refine unrelated backlog.

Before reading or editing backlog content, identify explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, ranges, or remote backlog references as paths). Only verify paths that are actually listed in `$ARGUMENTS`; do not require or infer the presence of any other files. If a listed path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing listed path(s) plus nearby candidate(s). Do not refine or commit anything when stopped.

## Remote backlog sources

Remote backlog references, such as Linear project identifiers, issue IDs, or issue URLs, are discovery inputs only. Do not refine against a moving remote source in place.

Before refining:

1. Resolve each remote reference using the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Fetch the exact remote items in the order implied by `$ARGUMENTS`.
3. Pin each remote item into a concrete local backlog entry or snapshot before refining:
   - prefer an existing local backlog file/item that already references the remote ID
   - otherwise create or update a repo-conventional local backlog snapshot that records the remote ID, title, fetched description/acceptance criteria, remote URL/key, and fetch timestamp/version if available
4. Refine the pinned local backlog entry or snapshot, not the remote text. Mirror the refined result back to the remote item only when the repo's convention and available tooling support it and the user expects it; otherwise keep refinement local and note that the remote item is unchanged.
5. Commit the local backlog snapshot and refinements only when task-related; do not mix them with unrelated changes.

If the remote item changes later, update the local backlog snapshot first, then re-refine against the new local text.

Local repo markdown backlogs remain first-class inputs. When `$ARGUMENTS` names local markdown backlog files, use them directly after path validation; do not force remote resolution or snapshot creation.

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
   - a strict available-to-begin status: only items with all blockers, dependencies, decisions, risks, product questions, and assumptions resolved from cited evidence may be marked ready
   - an item-scoped implementation snapshot in that item's existing structure:
     - goal / product intent
     - target file area, components, APIs, or data model involved
     - resolved decisions and assumptions, with the source evidence used for each
     - last known validation or evidence from the backlog text, if any
     - pending verification required before the item can be considered done
     - next recommended implementation action
4. Add a short item-specific add-on only when it helps the implementer:
   - least confident resolved assumption and the evidence supporting it
   - biggest non-obvious thing the implementer may be missing
   - one optional outstanding idea that is explicitly out of scope unless chosen
5. Remove ambiguity, duplicated tasks, stale assumptions, and solution-shaped instructions that are not required.
6. Keep tasks outcome-focused. Do not over-prescribe implementation unless the repo already has a clear matching pattern.
7. Eliminate blockers before making an item available. "Available to begin" means a lesser coding agent can start and complete the item without asking product, design, or architecture questions; without discovering unknown dependencies; and without relying on uncited or unresolved assumptions. Resolve missing decisions from existing backlog, repository, issue, product, or design context when the answer is already explicit. If a blocker cannot be resolved from available context, do not leave the item in the ready implementation queue: either split out a prerequisite decision/research item with concrete acceptance criteria, or clearly mark the affected item as blocked/unavailable and state the exact missing decision needed. Do not describe any item with unresolved blockers, open product questions, unknown dependencies, ambiguous acceptance criteria, or latent assumptions as implementation-ready.

After editing:

- Verify the refined backlog still covers every item from `$ARGUMENTS`.
- Perform a final readiness check for each refined item before committing: confirm every item marked available to begin has resolved evidence for scope, dependencies, decisions, assumptions, acceptance criteria, and verification.
- If any blocker, latent assumption, dependency, or product question remains unresolved after refinement, list the unresolved issue(s) in the output, identify the affected backlog item(s), and confirm those item(s) were left blocked/unavailable rather than implementation-ready.
- Run only formatting or validation that applies to the edited backlog files.
- Commit the changes with a concise message.
