Refine the backlog items in `$ARGUMENTS` into implementation-ready work for a lesser coding agent, then commit changes.

Treat `$ARGUMENTS` as the exact backlog item IDs, titles, or ranges to refine. Do not refine unrelated backlog.

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
7. If a backlog item is blocked by missing product information, mark the exact question needed and refine everything else around it.

After editing:

- Verify the refined backlog still covers every item from `$ARGUMENTS`.
- Run only formatting or validation that applies to the edited backlog files.
- Commit the changes with a concise message.
