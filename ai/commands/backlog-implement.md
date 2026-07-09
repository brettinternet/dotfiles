---
description: Implement the next open backlog items in an isolated worktree with parallel subagents, verify, commit, and integrate per the repo's flow (merge to local main or open a PR) (subagent escalation pattern)
argument-hint: <backlog-file|remote-refs> [item-ids|titles|ranges]
---

Fan out subagents and orchestrate to implement the next open backlog items from `$ARGUMENTS` in an isolated worktree/subtree. Preserve existing unstaged work, use the smallest targeted verification loop, commit only task-related work, integrate it per the repo's flow (merge to local main or open a PR), and clean up the worktree.

Treat `$ARGUMENTS` as the exact local backlog file, remote backlog references (such as Linear project identifiers, issue IDs, or issue URLs), item IDs, titles, or ranges to implement. Do not implement unrelated backlog items.

Before creating a worktree/subtree or editing anything, identify any explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, ranges, or remote backlog references as paths). If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not implement or commit anything when stopped.

## Backlog storage policy

Derive storage behavior per resolved backlog source from repository context:

- a local markdown backlog file named in `$ARGUMENTS` is a writable backlog source
- a remote item makes an existing local backlog entry writable only when exactly one repo markdown file matches it structurally as a backlog — an item list or item headings carrying the item's ID — not merely any file that mentions the ID
- every other remote item is remote-only: never write repo backlog/spec/planning markdown for it

Never create new backlog/spec/planning markdown unless the repo already demonstrates that exact convention, such as existing snapshot or spec files matching remote item IDs. When in doubt, do not create files; write only to writable backlog sources. Moving or renaming an existing backlog file into the repo's archive location per repo convention is an edit to an existing source, not creation.

Remote backlog sources:

Remote backlog references, such as Linear project identifiers, issue IDs, or issue URLs, are discovery inputs only. Do not implement directly against a moving remote source.

Invoking this command with remote backlog references is the standing authorization to update those exact remote items' status through the first-party tool — mark an item done or merged when its work is integrated. It does not authorize editing remote item content, creating or deleting remote items, or touching items outside `$ARGUMENTS`.

Before implementing:

1. Resolve each remote reference using the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Fetch the exact remote items in the order implied by `$ARGUMENTS`.
3. Pin each remote item into an exact resolved backlog source: its writable local backlog entry when one exists, a new snapshot file only when the repo's creation convention permits it, otherwise handoff notes, command-local notes, or a temporary file outside the worktree.
4. Implement against the pinned source, not the moving remote text. If the remote item changes later, refresh the pinned source first, then re-evaluate implementation state against the new pinned text.
5. Record backlog state in the item's writable backlog source; for remote-only items, update the remote item's status through the authorized first-party flow and record everything else in the final report.

Local repo markdown backlogs remain first-class inputs. When `$ARGUMENTS` names local markdown backlog files, use them directly after path validation and modify, complete, or archive them following their existing style. Local markdown that is not a writable backlog source is read-only context.

Before editing:

1. Inspect the current worktree status, preserve unrelated unstaged or untracked work, and do not block on unrelated dirty changes unless they prevent safe isolation; document ignored unrelated changes in the final report.
2. Identify the next open item or items from `$ARGUMENTS`.
3. Read the full item text, acceptance criteria, nearby backlog context, and relevant existing code patterns.
4. Confirm the item is small enough to complete safely. If it is oversized, split only the execution plan; do not silently shrink the requested acceptance.
5. Create or switch to an isolated worktree/subtree for the implementation so local user work is not disturbed.

Parallelization:

- Fan out subagents for independent file areas, tests, UI, migrations, or investigation.
- Use explore agents for read-only discovery and evidence gathering; keep the orchestrating context for decisions, synthesis, and shared-interface coordination.
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
- Hard anti-blocking rule: failed checks, item-scoped verification failures, missing required code, and flaky or outdated tests caused by or required for the current backlog item are implementation work to resolve immediately. Fix them in-repo, update code/tests/fixtures/config as needed, and rerun targeted verification; unrelated failures or dirty changes may be ignored only after recording why they are unrelated to `$ARGUMENTS`; stop only for a truly external product decision, unavailable dependency, or unsafe ambiguity after exhausting repo fixes and the oracle check.
- If product information is missing, implement everything not blocked and record the exact remaining decision instead of guessing.
- Before committing to a new architectural pattern or choosing between materially different designs, consult the oracle agent for a second opinion on the tradeoff. This is proactive design input, separate from the blocker escalation below.
- Before raising any notable blocker, missing product decision, failed acceptance, risky ambiguity, or inability to proceed to the user, consult the oracle agent for a second opinion on whether the blocker is real and whether there is a safe implementation path. If the oracle agent confirms or cannot resolve it, explicitly report it as a human-required blocker.

Completion criteria:

- Treat a backlog item as complete only when every stated or implied acceptance criterion is implemented and verified.
- Record completion in the item's writable backlog source. For remote-only items, mark the item done or merged through the first-party tool; when the tool cannot express that status, skip the update and report it. Do not create local markdown to record completion; report the complete/verified state and exact pinned remote source in the final response.
- If any required acceptance is not done, leave the item open and state exactly what remains.
- At the end, make the continuation status unambiguous:
  - `NEXT CONTEXT REQUIRED` when there is any remaining open backlog work, oracle-confirmed blocker, missing product decision, scoped verification failure that cannot be fixed in-repo, or writable local markdown backlog file that remains unarchived when archiving is required. Include the exact next item to start from and what context the next agent needs.
  - `BACKLOG COMPLETE AND ARCHIVED` only when every item from `$ARGUMENTS` is complete, verified, committed, integrated (merged locally or PR opened), each writable local markdown backlog file has been archived, and each remote-only item is marked done or merged through the first-party tool or its skipped status update is reported. Include the exact final item completed and where it was archived, or the remote status applied for remote-only sources.

Verification:

- Use the smallest targeted verification loop that proves the change: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- Before marking an item complete, run the verifier agent with the item's acceptance criteria and the implementation commits — not your conclusions — and treat any FAIL or UNVERIFIED criterion as open work.
- Re-run targeted verification after fixes. If verification fails, diagnose the root cause, fix all in-scope code/tests/checks in-repo, and rerun before reporting a blocker; if the failure is unrelated to the current item, record the evidence and continue with targeted verification.
- Unrelated failing tests or unrelated dirty changes do not block finishing the item or reporting it complete; note them separately, and do not fix or commit them as part of this work.
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
- Then report the completed item IDs/titles, commits made, verification run, integration result (local merge or PR URL), archive location if applicable (or not applicable for remote-only sources), any ignored unrelated failures or dirty changes, and any remaining blockers or product decisions.
