Refine the backlog items in `$ARGUMENTS` into implementation-ready work for a lesser coding agent, then commit changes.

Treat `$ARGUMENTS` as the exact backlog item IDs, titles, or ranges to refine. Do not refine unrelated backlog.

Before reading or editing backlog content, identify any explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, or ranges as paths). If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not refine or commit anything when stopped.

For each backlog item:

1. Read the existing backlog text and nearby context before editing.
2. Preserve the product intent, but split vague or oversized work into small, independently executable tasks.
3. Add enough implementation context for a lesser coding agent:
   - target files, components, commands, and existing patterns to inspect
   - explicit non-goals and scope boundaries
   - dependencies and required ordering
   - edge cases, data states, migrations, permissions, and failure modes
   - acceptance criteria that can be verified without guessing
   - the specific tests, checks, or manual QA expected
   - an item-scoped implementation snapshot in that item's existing structure:
     - goal / product intent
     - target file area, components, APIs, or data model involved
     - open risks, blockers, missing decisions, and product questions
     - last known validation or evidence from the backlog text, if any
     - pending verification required before the item can be considered done
     - next recommended implementation action
4. Add a short item-specific add-on only when it helps the implementer:
   - least confident assumption
   - biggest non-obvious thing the implementer may be missing
   - one optional outstanding idea that is explicitly out of scope unless chosen
5. Remove ambiguity, duplicated tasks, stale assumptions, and solution-shaped instructions that are not required.
6. Keep tasks outcome-focused. Do not over-prescribe implementation unless the repo already has a clear matching pattern.
7. If a backlog item is blocked by missing product information, resolve the missing decision from existing backlog context when the answer is already explicit. If any product question remains open, mark the exact question needed, refine everything else around it, and do not describe that item as implementation-ready.

After editing:

- Verify the refined backlog still covers every item from `$ARGUMENTS`.
- If any product question remains open after refinement, list the unresolved question(s) in the output, identify the affected backlog item(s), and stop short of claiming those item(s) are implementation-ready.
- Run only formatting or validation that applies to the edited backlog files.
- Commit the changes with a concise message.
