---
description: Implement the next open backlog items in an isolated worktree, verify independently, commit, and integrate per the repo's flow
argument-hint: <backlog-file|remote-refs> [item-ids|titles|ranges]
---

Implement the next open backlog items from `$ARGUMENTS` in an isolated worktree/subtree. Preserve existing unstaged work, use the smallest targeted verification loop, commit only task-related work, integrate it per the repo's flow (merge to local main or open a PR), and clean up the worktree.

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

Invoking this command with remote backlog references is the standing authorization to update those exact remote items through the first-party tool: post `implemented:`/`blocked:` progress comments and mark an item done or merged when its work is integrated. It does not authorize editing remote item content otherwise, creating or deleting remote items, or touching items outside `$ARGUMENTS`.

Before implementing:

1. Resolve each remote reference using the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Fetch the exact remote items in the order implied by `$ARGUMENTS`, including existing progress comments.
3. Pin each remote item into an exact resolved backlog source: its writable local backlog entry when one exists, a new snapshot file only when the repo's creation convention permits it, otherwise command-local notes or a temporary file outside the worktree. Final-report or handoff text is not a durable backlog source.
4. Implement against the pinned source, not the moving remote text. If the remote item changes later, refresh the pinned source first, then re-evaluate implementation state against the new pinned text.
5. Record every completed task in the item's writable backlog source. For remote-only items, post an `implemented:` progress comment and update final workflow status through the authorized first-party flow. If the tool cannot write comments, do not begin a multi-pass remote-only item because durable intermediate state is unavailable.

Local repo markdown backlogs remain first-class inputs. When `$ARGUMENTS` names local markdown backlog files, use them directly after path validation and modify, complete, or archive them following their existing style. Local markdown that is not a writable backlog source is read-only context.

Before editing:

1. Inspect the current worktree status, preserve unrelated unstaged or untracked work, and do not block on unrelated dirty changes unless they prevent safe isolation; document ignored unrelated changes in the final report.
2. Identify the first open item from `$ARGUMENTS`. Process multiple items only when `$ARGUMENTS` explicitly selects those item IDs, titles, or a range; naming only a backlog file or remote project selects its first open item.
3. Read the full item text, explicit tasks, acceptance criteria, nearby backlog context, durable progress markers, and relevant existing code patterns.
4. Select the first explicit open task as the coherent implementation unit. Include inseparable production code, required callsites, fixtures or migrations, and tests for that outcome instead of treating them as separate passes.
5. Treat task sizing from backlog refinement as authoritative. If a writable local item has no explicit tasks, or its first task contains multiple independently useful behaviors or crosses independent subsystems without one atomic contract, split it into named ordered item-local tasks before coding, map all acceptance criteria to those tasks, and commit the refinement. For a remote-only unrefined or oversized item, stop and invoke `backlog-refine` because this command is not authorized to rewrite remote item content. Never stop at an unnamed internal slice.
6. Create or switch to an isolated worktree/subtree for the implementation so local user work is not disturbed.

## Invocation boundary and durable progress

One invocation implements, verifies, records, and commits exactly one coherent task from the current item. It may complete the item when that task is its final task, but it must stop before the next independently verifiable task even when more scoped work remains. Explicitly selecting multiple items controls eligible order; it does not multiply the one-task pass budget.

The writable backlog item is authoritative state; remote item comments are authoritative for remote-only items. The final report is only a reproducible summary. Before ending the invocation, persist:

- item status: `in-progress`, `blocked`, or `complete`, following existing source vocabulary
- completed task and implementation commit
- targeted verification command and exact result
- exact next task and remaining acceptance criteria

For a writable backlog source, update the item and commit its task state. If no existing style fits, use:

`implemented: <task>; commit: <commit>; verified: <command/result>; status: <in-progress|complete>; next: <task|COMPLETE>; remaining: <acceptance criteria|none>`

For a remote-only item, post the same line as a progress comment. If durable write-back fails, do not claim the task complete; retain the coherent code commit, report the failure, and make repairing durable state the next action.

Subagent budget:

- Default to direct implementation. A small item, a tightly coupled change, or work in one subsystem does not justify delegation.
- Delegate within this budget only when the scoped work has materially substantial, independent branches; otherwise implement directly.
- Use at most four subagents for the entire invocation: no more than two `explore` or `executor` workers combined, one final batched `verifier` covering all completed items, and at most one `oracle` consultation when an explicit trigger below is met. This is a total budget, not a concurrency limit; do not replace finished agents with new ones.
- Delegate only materially substantial, independent work whose target, acceptance criteria, and non-goals can be specified up front. Use an `explore` agent only when the relevant surface is genuinely unknown or spans independent subsystems; use an `executor` only for a disjoint file area with settled interfaces.
- Keep shared-interface changes, small lookups, tests coupled to an implementation, decisions, synthesis, and integration in the active agent. Do not create one agent per backlog item, file, acceptance criterion, or test.
- If more work is parallelizable than the budget permits, delegate the highest-risk or highest-latency branches and perform the rest directly. Run formatting, linting, and broad validation once at the end unless a smaller check is needed to unblock implementation.

Implementation rules:

- Implement the real behavior required by the backlog item, not a scaffold, TODO, mock, fake fallback, or warning suppression.
- Reuse existing repository patterns and shared code where they fit.
- Keep changes limited to the backlog item and required callsites.
- Delete obsolete code paths created by the change. Do not leave compatibility shims unless the item explicitly requires them.
- Add or update tests for behavior, edge cases, and failure modes implied by the item.
- Hard anti-blocking rule: failed checks, item-scoped verification failures, missing required code, and flaky or outdated tests caused by or required for the current backlog item are implementation work to resolve immediately. Fix them in-repo, update code/tests/fixtures/config as needed, and rerun targeted verification; unrelated failures or dirty changes may be ignored only after recording why they are unrelated to `$ARGUMENTS`; stop only for a truly external product decision, unavailable dependency, or unsafe ambiguity after exhausting repo fixes and the oracle check.
- If product information is missing, implement everything not blocked and record the exact remaining decision instead of guessing.
- Use the one optional oracle consultation only after gathering repository evidence, and only for consequential, hard-to-reverse design tradeoffs or a possible genuine external blocker. Batch related questions; do not consult for ordinary choices or routine check failures.
- Before reporting a human-required blocker, include the exact blocker, attempted paths, and evidence in that consultation. Report it as human-required only if no safe, repo-evidenced path remains.

After implementation:

1. Run the smallest targeted verification loop that proves the completed task.
2. Commit the coherent implementation. Record its task name, commit, verification result, status, and exact next task in the writable backlog source; when the implementation commit cannot be named in the same commit, immediately add one state-only commit naming it.
3. For remote-only items, post the equivalent `implemented:` comment. Do not use the final report as the progress store.
4. If another task remains, stop with `NEXT CONTEXT REQUIRED`; do not begin it in this invocation.

Completion criteria:

- Treat a backlog item as complete only when every explicit task and every stated or implied acceptance criterion is implemented and verified.
- Record completion in the item's writable backlog source. For remote-only items, first post the required `implemented:` comment with `status: complete` and `remaining: none`, then mark the item done or merged through the first-party tool. If the tool cannot express the workflow transition, report that limitation; if the durable completion comment fails, leave the item incomplete with `NEXT CONTEXT REQUIRED`. Do not create local markdown solely to record remote completion.
- If any required task or acceptance is not done, leave the item durably `in-progress` with its exact next task.
- At the end, make the continuation status unambiguous:
  - `NEXT CONTEXT REQUIRED` when there is any remaining open task or backlog work, durable-state write-back failure, oracle-confirmed blocker, missing product decision, scoped verification failure that cannot be fixed in-repo, or writable local markdown backlog file that remains unarchived when archiving is required. Include the exact next item and task.
  - `BACKLOG COMPLETE AND ARCHIVED` only when every explicitly scoped item is complete, verified, committed, integrated (merged locally or PR opened), each writable local markdown backlog file has been archived, and each remote-only item has durable `status: complete; remaining: none` item state and is marked done or merged when the first-party tool supports that workflow transition. Include the exact final item completed and where it was archived, or the remote state and workflow transition applied.

Verification:

- Use the smallest targeted verification loop that proves the change: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- Before marking an item complete, run one final verifier agent over that item, with its acceptance criteria and accumulated implementation commits — not your conclusions — and treat any FAIL or UNVERIFIED criterion as open work. Do not run the final verifier merely because one non-final task completed.
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

- Commit only task-related implementation and durable state changes with concise messages.
- Integrate only when the current item is complete; otherwise retain the isolated branch/worktree and report its exact location for the next invocation.
- Start the final report with exactly one status line: `NEXT CONTEXT REQUIRED` or `BACKLOG COMPLETE AND ARCHIVED`.
- Then reproduce the durable state: backlog source, current item, completed task, implementation and state commits, verification, exact next task, retained worktree or integration result, archive location if applicable, ignored unrelated failures or dirty changes, blockers, and any failed remote write-back.
