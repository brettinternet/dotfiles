Refine the backlog items in `$1` into implementation-ready work for a lesser coding agent, then commit changes.

Treat `$1` as the exact backlog item IDs, titles, or ranges to refine. Do not refine unrelated backlog.

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
4. Remove ambiguity, duplicated tasks, stale assumptions, and solution-shaped instructions that are not required.
5. Keep tasks outcome-focused. Do not over-prescribe implementation unless the repo already has a clear matching pattern.
6. If a backlog item is blocked by missing product information, mark the exact question needed and refine everything else around it.

After editing:

- Verify the refined backlog still covers every item from `$1`.
- Run only formatting or validation that applies to the edited backlog files.
- Commit the changes with a concise message.
