---
description: Run one pass of the backlog implement→review loop — implement or review the next scoped item, commit, and hand off the next state
argument-hint: <backlog-files|remote-refs> [item-ids|titles|ranges]
---

Run one pass of the backlog implementation/review loop for `$ARGUMENTS`, commit any task-related change, and leave a concise handoff for the next pass.

This command alternates between two states for each backlog item:

1. `IMPLEMENT` — build the next open item that is not demonstrably implemented.
2. `REVIEW` — when the item appears implemented already, review that implementation for correctness, security, performance, and code design before marking it complete.

Treat `$ARGUMENTS` as the exact local backlog file, ordered list of local backlog files, or remote backlog references such as Linear project/issue IDs, plus optional item IDs, titles, or ranges to work through. Do not implement or review unrelated backlog items.

Each pass must be prepared to either implement the next unfinished scoped backlog work in order or review an implementation that already appears present.

## Loop driver

This is a handoff-style loop, not a forever-running process. A single pass ends by telling the next agent what to do:

- after an `IMPLEMENT` pass, review the same backlog item and implementation commit
- after a `REVIEW` pass that commits fixes, review the same item again using the review-fix commit
- after a clean `REVIEW` pass with no remaining findings, find and implement the next unfinished scoped backlog item in the current backlog file, then the next listed backlog file, or archive when none remain
- after `ARCHIVE`, stop only when the final status is `BACKLOG COMPLETE AND ARCHIVED`

Do not assume prior chat. Start by finding the next unfinished scoped backlog work in the listed backlog order or the implementation that needs review.

Before creating a worktree/subtree, reviewing, or editing anything, identify every explicit local backlog file path, remote backlog reference, and any other explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, or ranges as paths). Validate listed local backlog files left-to-right before editing any of them. If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not implement, review, fix, or commit anything when stopped.

## Remote backlog sources

Remote backlog references, such as Linear project identifiers, issue IDs, or issue URLs, are discovery inputs only. Do not run the implementation loop directly against a moving remote source.

Before implementation or review:

1. Resolve each remote reference using the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Fetch the exact remote items in the order implied by `$ARGUMENTS`.
3. Pin each remote item into a concrete local backlog entry or snapshot before code edits:
   - prefer an existing local backlog file/item that already references the remote ID
   - otherwise create or update a repo-conventional local backlog snapshot that records the remote ID, title, fetched acceptance criteria, remote URL/key, and fetch timestamp/version if available
4. Commit the local backlog snapshot or update only when it is task-related and useful for the loop; otherwise keep it as a clearly scoped local working snapshot and do not mix it with unrelated changes.
5. Apply `reviewed:` and `blocked:` markers only to the local backlog entry or snapshot, not only to the remote system.

If the remote item changes later, update the local backlog snapshot first, then re-evaluate review and blocker markers against the new local text. Ordered runs may mix local backlog files and remote references, but the loop operates only on the resolved local backlog entries after this step.

Local repo markdown backlogs remain first-class inputs. When `$ARGUMENTS` names local markdown backlog files, use them directly after path validation; do not force remote resolution or snapshot creation.

## Target selection

Determine exactly one current target:

1. Inspect the current worktree status and preserve unrelated unstaged or untracked work.
2. Read the resolved backlog file or files in the order supplied, including matching item text, acceptance criteria, nearby backlog context, remote-source snapshots if present, and any existing implementation, review, or blocker notes.
3. Identify the first scoped resolved backlog file, then the first scoped item in that file, that is still open, incomplete, unreviewed, or blocked without a still-valid blocker marker.
4. Skip an item with a valid `blocked:` marker only when its unblock condition is still unmet and the evidence has not changed. Record the skip in the handoff and continue to the next scoped item in order.
5. Determine the pass state:
   - `IMPLEMENT` when required behavior is absent, incomplete, failing verification, or not traceable to a commit.
   - `REVIEW` when the behavior appears implemented, has an implementation commit or changed files to inspect, and lacks a valid review marker for that exact implementation.
   - `BLOCKED` only when a required product decision, unavailable dependency, or unsafe ambiguity prevents both implementation and review and no valid blocker marker already records the same blocker.
6. If multiple files or items are explicitly requested, preserve the supplied backlog file order and process only the smallest safe batch whose acceptance criteria and verification can be completed in this pass. Leave the next exact file and item in the handoff.

Do not skip an open item because a later item or later backlog file looks easier. If the next item is oversized, split only the execution plan; do not silently shrink acceptance.

## Handoff contract

At the end of every pass, write the next step clearly enough for another agent to continue:

- current resolved backlog file and item ID/title
- ordered backlog source list and local resolution map, when more than one source was supplied
- state to run next: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- implementation commit(s), review-fix commit(s), or changed files to inspect
- acceptance criteria already verified
- verification commands already run and exact results
- remaining acceptance criteria, risks, blockers, product decisions, and any blocked items skipped this pass
- exact next backlog file, item, and command invocation to start from

Use `NEXT CONTEXT REQUIRED` whenever any scoped backlog work remains open, blocked, unreviewed, unarchived, or not integrated. Use `BACKLOG COMPLETE AND ARCHIVED` only when every scoped item across every supplied backlog file is implemented, reviewed, verified, committed, integrated (merged locally or PR opened), and each backlog file has been archived.

## Review markers

To avoid reviewing the same implementation repeatedly, mark the backlog item itself as reviewed only after a clean `REVIEW` pass verifies every acceptance criterion and either makes no changes or verifies all review fixes.

Store the marker inside the item’s existing notes, status, or conclusion area. Follow the backlog file’s existing style; if there is no style, add one concise item-local line:

`reviewed: <implementation-commit> [review-fix: <commit>]; verified: <brief command/result>`

A review marker is valid only for the exact implementation commit it names, plus the review-fix commit when present. If the implementation commit changes, review-fix commit changes, acceptance criteria change, or relevant files change without an updated marker, treat the item as `REVIEW` again. If the marker is valid and the item is complete, do not re-review it; move to the next unfinished scoped item in the ordered backlog list.

## Blocker markers

To avoid repeating the same blocker forever, mark the backlog item itself as blocked only after exhausting repository context, attempting all safe unblocked work, and consulting the oracle/smart/slow agent for a second opinion.

Store the marker inside the item’s existing notes, status, or conclusion area. Follow the backlog file’s existing style; if there is no style, add one concise item-local line:

`blocked: <short reason>; tried: <brief attempted path>; unblock: <specific decision/dependency/evidence needed>`

A blocker marker is valid only while the reason, attempted path, and unblock condition still match the current code, backlog text, dependencies, and verification evidence. Skip a blocked item only when its marker is still valid. Re-enter it automatically when new information appears, dependencies become available, acceptance criteria change, relevant code changes, or the unblock condition no longer matches; then clear or replace the marker and continue with `IMPLEMENT` or `REVIEW`. If every remaining scoped item is blocked by still-valid markers, stop with `NEXT CONTEXT REQUIRED` and report the blocker list.

## IMPLEMENT pass

Before editing:

1. Create or switch to an isolated worktree/subtree for the implementation so local user work is not disturbed.
2. Read relevant existing code patterns before designing a new one.
3. Map required callsites, data flows, tests, migrations, and UI/API behavior from the backlog item.
4. Coordinate shared interfaces before parallel edits when tasks touch the same API, schema, type, or command.

Parallelization:

- Fan out subagents for independent file areas, tests, UI, migrations, or investigation.
- Give each subagent the exact target, scope boundaries, acceptance criteria, and non-goals.
- Do not serialize work that can safely happen in parallel.
- Run formatting, linting, and broad validation once at the end unless a smaller check is needed to unblock a subagent.

Implementation rules:

- Implement the real behavior required by the backlog item, not a scaffold, TODO, mock, fake fallback, or warning suppression.
- Reuse existing repository patterns and shared code where they fit.
- Keep changes limited to the backlog item and required callsites.
- Delete obsolete code paths created by the change. Do not leave compatibility shims unless the item explicitly requires them.
- Add or update tests for behavior, edge cases, and failure modes implied by the item.
- If product information is missing, implement everything not blocked and record the exact remaining decision instead of guessing.
- Before raising any notable blocker, missing product decision, failed acceptance, risky ambiguity, or inability to proceed to the user, consult the oracle/smart/slow agent for a second opinion on whether the blocker is real and whether there is a safe implementation path. If the oracle/smart/slow agent confirms or cannot resolve it, explicitly report it as a human-required blocker.

After implementation:

1. Run the smallest targeted verification loop that proves the change: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
2. Commit only task-related implementation work with a concise message.
3. Do not mark the backlog item complete yet unless the same pass also performs the `REVIEW` gate after the implementation commit.
4. Leave the next state as `REVIEW` with the exact implementation commit(s), files, and verification evidence.

## REVIEW pass

Use this path when the target item appears already implemented, either from a previous pass, existing commits, or current task-related changes.

Review process:

1. Establish intent before judging the code:
   - read the relevant backlog item, issue, PR description, commit messages, or nearby documentation
   - identify expected user-visible behavior and non-goals
   - map the files, callsites, data flows, and tests affected by the implementation
2. Evaluate correctness first:
   - verify every stated or implied acceptance criterion is satisfied
   - check edge cases, error paths, empty states, retries, concurrency, permissions, migrations, and rollback behavior
   - look for partial fixes, stale shims, dead paths, duplicated logic, behavior hidden behind feature flags or defaults, and unreviewed callsites
3. Evaluate security:
   - authentication and authorization boundaries
   - tenant/org/user scoping
   - secret handling and logging
   - injection, traversal, SSRF, XSS, CSRF, deserialization, and unsafe shell/process use where relevant
   - data exposure through errors, telemetry, caching, or client state
4. Evaluate performance:
   - avoidable allocations, copies, repeated work, N+1 queries, unbounded loops, blocking I/O, large payloads, and cache invalidation
   - database indexes, query shapes, pagination, batching, and transaction scope where relevant
   - frontend render churn, bundle growth, waterfalls, and unnecessary client work where relevant
5. Evaluate code quality and maintainability:
   - fit with existing repository patterns
   - clear ownership boundaries and minimal surface area
   - simple names, types, invariants, and failure modes
   - tests that defend behavior instead of implementation trivia
   - no unnecessary abstractions, comments, TODOs, compatibility shims, or drive-by rewrites
6. Evaluate latent failure modes:
   - answer: `If this breaks in 3 months, what’s the most likely reason?`
   - tie the risk to a concrete mechanism: ownership drift, unchecked edge case, schema/API change, concurrency, permissions, data volume, dependency behavior, missing test coverage, or unclear invariant
   - decide whether the risk must be addressed now or can be left as a follow-up, and state why

Fix policy:

- Fix valid issues at the source, not by suppressing warnings or narrowing tests.
- Keep fixes limited to `$ARGUMENTS` and directly required callsites.
- Add or update targeted tests for behavioral fixes.
- If a finding needs product input, leave the code unchanged for that point and state the exact decision needed.
- If the implementation is already sound, make no code changes.

After review:

1. Run the specific tests, linters, typechecks, or manual QA that cover reviewed or fixed behavior.
2. Commit any review fixes with a concise message.
3. Write or update the item-local `reviewed:` marker when every acceptance criterion is implemented, reviewed, and verified.
4. Mark the backlog item complete only after the valid review marker is present.
5. If any required acceptance is not done, leave the item open and state exactly what remains.
6. Integrate completed work using the resolved flow (see Integration) when the scoped item or safe batch is complete.
7. Clean up the temporary worktree/subtree after integration; keep the pushed branch under `pull-request`.
8. If all scoped backlog items across all supplied backlog files are complete, verified, committed, integrated, and reviewed, archive each backlog file according to existing repo conventions.

## BLOCKED pass

Use `BLOCKED` only after exhausting repository context and consulting the oracle/smart/slow agent for a second opinion.

When blocked:

- Implement and verify any acceptance criteria that are safely unblocked before marking the item blocked.
- Do not mark the item complete.
- Write or update the item-local `blocked:` marker with the exact missing decision, unavailable dependency, failed acceptance criterion, or unsafe ambiguity; include what was tried and the next concrete unblock action.
- Commit only if the committed state is coherent and useful; otherwise leave the worktree uncommitted and explain why.
- Move the next pass to the next scoped item whose blocker marker is absent, stale, or resolved. Do not keep selecting the same still-blocked item.
- Leave `NEXT CONTEXT REQUIRED` with the skipped blocker list and the next unblocked target. If no unblocked target remains, report the human-required blocker queue instead of archiving.

## Verification

- Use the smallest targeted verification loop that proves the change or review finding: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- Re-run targeted verification after fixes.
- Do not claim project-wide health unless project-wide checks were actually run.
- Formatting, linting, and broad validation happen once at the end unless needed earlier to unblock work.

## Integration

Resolve the finish flow before pushing, merging, or opening anything:

1. If the repo's `CLAUDE.md`, `AGENTS.md`, or backlog config declares a flow (e.g. an `Integration: pull-request` or `Integration: local-merge` line), obey it. For `pull-request`, use the declared base branch (default `main`) and branch prefix if given.
2. Otherwise auto-detect: if you lack push access to the base branch, the base branch is protected, or `origin` is a shared remote you do not own, use `pull-request`. Otherwise use `local-merge`.
3. When still ambiguous, default to `local-merge`.

- `local-merge`: merge the completed, verified work back to local `main`; clean up the temporary worktree/subtree; do not push.
- `pull-request`: push the task branch to `origin` and open a PR against the base branch with `gh`, using a concise title and body summarizing the item and verification; clean up the worktree but keep the pushed branch; do not merge locally and do not merge the PR; report the PR URL and recommend `/pr-babysit [reviewer]` as the follow-up to drive it to green and approval. Invoking this command is the standing instruction to push and open the PR for this task's own branch only — it overrides the global "never push / never open PRs without explicit instruction" rule for that branch, and does not authorize force-pushing, merging, or touching unrelated branches.

## Finish

Commit behavior:

- Commit only task-related work.
- Use concise commit messages.
- Do not include unrelated preserved user work.
- Do not push unrelated work. Under `pull-request` flow, pushing the task branch and opening its PR is authorized by invoking this command (see Integration); do nothing beyond that branch.

Final response must start with exactly one status line:

`NEXT CONTEXT REQUIRED`

or

`BACKLOG COMPLETE AND ARCHIVED`

Then report:

- backlog source list, resolved local backlog file list, and item ID/title processed
- pass state completed: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- commits made
- integration result: local merge or PR URL, when the scoped item or batch was integrated this pass
- verification run
- review result, including correctness/security/performance/design findings
- most likely 3-month breakage reason and whether to address it now or later
- archive location if applicable
- exact next item and state for the next pass, if any
- copy-pasteable next prompt that invokes this command with the backlog file, item, and commit/files to inspect when relevant
- remaining blockers, skipped blocked items, risks, or product decisions
