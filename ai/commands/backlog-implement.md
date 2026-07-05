Fan out subagents and orchestrate to implement the next open backlog items from `$ARGUMENTS` in an isolated worktree/subtree. Preserve existing unstaged work, use the smallest targeted verification loop, commit only task-related work, merge back to local main when done, and clean up the worktree.

Treat `$ARGUMENTS` as the exact backlog file, item IDs, titles, or ranges to implement. Do not implement unrelated backlog items.

Before creating a worktree/subtree or editing anything, identify any explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, or ranges as paths). If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory, the nearest existing parent directory, or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not implement or commit anything when stopped.

Before editing:

1. Inspect the current worktree status and preserve unrelated unstaged or untracked work.
2. Identify the next open item or items from `$ARGUMENTS`.
3. Read the full item text, acceptance criteria, nearby backlog context, and relevant existing code patterns.
4. Confirm the item is small enough to complete safely. If it is oversized, split only the execution plan; do not silently shrink the requested acceptance.
5. Create or switch to an isolated worktree/subtree for the implementation so local user work is not disturbed.

Parallelization:

- Fan out subagents for independent file areas, tests, UI, migrations, or investigation.
- Give each subagent the exact target, scope boundaries, acceptance criteria, and non-goals.
- Do not serialize work that can safely happen in parallel.
- Coordinate shared interfaces before parallel edits when tasks touch the same API, schema, type, or command.
- Run formatting, linting, and broad validation once at the end unless a smaller check is needed to unblock a subagent.

Implementation rules:

- Implement the real behavior required by the backlog item, not a scaffold, TODO, mock, fake fallback, or warning suppression.
- Reuse existing repository patterns and shared code where they fit.
- Keep changes limited to the backlog item and required callsites.
- Delete obsolete code paths created by the change. Do not leave compatibility shims unless the item explicitly requires them.
- Add or update tests for behavior, edge cases, and failure modes implied by the item.
- If product information is missing, implement everything not blocked and record the exact remaining decision instead of guessing.

Completion criteria:

- Mark a backlog item complete only when every stated or implied acceptance criterion is implemented and verified.
- If any required acceptance is not done, leave the item open and state exactly what remains.
- At the end, make the continuation status unambiguous:
  - `NEXT CONTEXT REQUIRED` when there is any remaining open backlog work, blocker, missing product decision, failed verification, or unarchived backlog file. Include the exact next item to start from and what context the next agent needs.
  - `BACKLOG COMPLETE AND ARCHIVED` only when every item from `$ARGUMENTS` is complete, verified, committed, merged back, and the backlog file has been archived. Include the exact final item completed and where it was archived.

Verification:

- Use the smallest targeted verification loop that proves the change: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- Re-run targeted verification after fixes.
- Do not claim project-wide health unless project-wide checks were actually run.

Finish:

- Commit only task-related work with a concise message.
- Merge the completed work back to local main.
- Clean up the temporary worktree/subtree.
- Start the final report with exactly one status line: `NEXT CONTEXT REQUIRED` or `BACKLOG COMPLETE AND ARCHIVED`.
- Then report the completed item IDs/titles, commits made, verification run, archive location if applicable, and any remaining blockers or product decisions.
