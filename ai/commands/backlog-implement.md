---
description: Implement the next open backlog items in an isolated worktree with parallel subagents, verify, commit, and integrate per the repo's flow (merge to local main or open a PR)
argument-hint: <backlog-file|remote-refs> [item-ids|titles|ranges]
---

Fan out subagents and orchestrate to implement the next open backlog items from `$ARGUMENTS` in an isolated worktree/subtree. Preserve existing unstaged work, use the smallest targeted verification loop, commit only task-related work, integrate it per the repo's flow (merge to local main or open a PR), and clean up the worktree.

Treat `$ARGUMENTS` as the exact local backlog file, remote backlog references (such as Linear project identifiers, issue IDs, or issue URLs), item IDs, titles, or ranges to implement. Do not implement unrelated backlog items.

Before creating a worktree/subtree or editing anything, identify any explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, ranges, or remote backlog references as paths). If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not implement or commit anything when stopped.

Remote backlog sources:

Remote backlog references, such as Linear project identifiers, issue IDs, or issue URLs, are discovery inputs only. Do not implement directly against a moving remote source.

Before implementing:

1. Resolve each remote reference using the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Fetch the exact remote items in the order implied by `$ARGUMENTS`.
3. Pin each remote item into a concrete local backlog entry or snapshot before code edits:
   - prefer an existing local backlog file/item that already references the remote ID
   - otherwise create or update a repo-conventional local backlog snapshot that records the remote ID, title, fetched acceptance criteria, remote URL/key, and fetch timestamp/version if available
4. Implement against the pinned local backlog entry or snapshot, not the remote text. Update the remote item's status only when the repo's convention and available tooling support it and the user expects it.

Local repo markdown backlogs remain first-class inputs. When `$ARGUMENTS` names local markdown backlog files, use them directly after path validation; do not force remote resolution or snapshot creation.

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
- Before raising any notable blocker, missing product decision, failed acceptance, risky ambiguity, or inability to proceed to the user, consult the oracle agent for a second opinion on whether the blocker is real and whether there is a safe implementation path. If the oracle agent confirms or cannot resolve it, explicitly report it as a human-required blocker.

Completion criteria:

- Mark a backlog item complete only when every stated or implied acceptance criterion is implemented and verified.
- If any required acceptance is not done, leave the item open and state exactly what remains.
- At the end, make the continuation status unambiguous:
  - `NEXT CONTEXT REQUIRED` when there is any remaining open backlog work, blocker, missing product decision, failed verification, or unarchived backlog file. Include the exact next item to start from and what context the next agent needs.
  - `BACKLOG COMPLETE AND ARCHIVED` only when every item from `$ARGUMENTS` is complete, verified, committed, integrated (merged locally or PR opened), and the backlog file has been archived. Include the exact final item completed and where it was archived.

Verification:

- Use the smallest targeted verification loop that proves the change: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- Re-run targeted verification after fixes.
- Do not claim project-wide health unless project-wide checks were actually run.

Integration:

Resolve the finish flow before pushing, merging, or opening anything:

1. If the repo's `CLAUDE.md`, `AGENTS.md`, or backlog config declares a flow (e.g. an `Integration: pull-request` or `Integration: local-merge` line), obey it. For `pull-request`, use the declared base branch (default `main`) and branch prefix if given.
2. Otherwise auto-detect: if you lack push access to the base branch, the base branch is protected, or `origin` is a shared remote you do not own, use `pull-request`. Otherwise use `local-merge`.
3. When still ambiguous, default to `local-merge`.

- `local-merge`: merge the completed, verified work back to local `main`; clean up the temporary worktree/subtree; do not push.
- `pull-request`: push the task branch to `origin` and open a PR against the base branch with `gh`, using a concise title and body summarizing the item and verification; clean up the worktree but keep the pushed branch; do not merge locally and do not merge the PR; report the PR URL and recommend `/pr-babysit [reviewer]` as the follow-up to drive it to green and approval. Invoking this command is the standing instruction to push and open the PR for this task's own branch only — it overrides the global "never push / never open PRs without explicit instruction" rule for that branch, and does not authorize force-pushing, merging, or touching unrelated branches.

Finish:

- Commit only task-related work with a concise message.
- Integrate the completed work using the resolved flow above.
- Start the final report with exactly one status line: `NEXT CONTEXT REQUIRED` or `BACKLOG COMPLETE AND ARCHIVED`.
- Then report the completed item IDs/titles, commits made, verification run, integration result (local merge or PR URL), archive location if applicable, and any remaining blockers or product decisions.
