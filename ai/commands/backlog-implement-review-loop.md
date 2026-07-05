Run one pass of the backlog implementation/review loop for `$ARGUMENTS`, commit any task-related change, and leave a concise handoff for the next pass.

This command alternates between two states for each backlog item:

1. `IMPLEMENT` — build the next open item that is not demonstrably implemented.
2. `REVIEW` — when the item appears implemented already, review that implementation for correctness, security, performance, and code design before marking it complete.

Treat `$ARGUMENTS` as the exact backlog file plus optional item IDs, titles, or ranges to work through. Do not implement or review unrelated backlog items.

Each pass must be prepared to either implement the next unfinished scoped backlog work or review an implementation that already appears present.

## Loop driver

This is a handoff-style loop, not a forever-running process. A single pass ends by telling the next agent what to do:

- after an `IMPLEMENT` pass, review the same backlog item and implementation commit
- after a `REVIEW` pass that commits fixes, review the same item again using the review-fix commit
- after a clean `REVIEW` pass with no remaining findings, find and implement the next unfinished scoped backlog item, or archive when none remain
- after `ARCHIVE`, stop only when the final status is `BACKLOG COMPLETE AND ARCHIVED`

Do not assume prior chat. Start by finding the next unfinished scoped backlog work or the implementation that needs review.

Before creating a worktree/subtree, reviewing, or editing anything, identify any explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, or ranges as paths). If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not implement, review, fix, or commit anything when stopped.

## Target selection

Determine exactly one current target:

1. Inspect the current worktree status and preserve unrelated unstaged or untracked work.
2. Read the backlog file, matching item text, acceptance criteria, nearby backlog context, and any existing completion/review notes.
3. Identify the first scoped item that is still open, incomplete, blocked, or missing a completed review gate.
4. Determine the pass state:
   - `IMPLEMENT` when required behavior is absent, incomplete, failing verification, or not traceable to a commit.
   - `REVIEW` when the behavior appears implemented, has an implementation commit or changed files to inspect, and needs validation before completion.
   - `BLOCKED` only when a required product decision, unavailable dependency, or unsafe ambiguity prevents both implementation and review.
5. If multiple items are explicitly requested, process only the smallest safe batch whose acceptance criteria and verification can be completed in this pass. Leave the next exact item in the handoff.

Do not skip an open item because a later item looks easier. If the next item is oversized, split only the execution plan; do not silently shrink acceptance.

## Handoff contract

At the end of every pass, write the next step clearly enough for another agent to continue:

- current backlog file and item ID/title
- state to run next: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- implementation commit(s) or changed files to inspect
- acceptance criteria already verified
- verification commands already run and exact results
- remaining acceptance criteria, risks, blockers, or product decisions
- exact next command invocation or item to start from

Use `NEXT CONTEXT REQUIRED` whenever any scoped backlog work remains open, blocked, unreviewed, unarchived, or not merged back. Use `BACKLOG COMPLETE AND ARCHIVED` only when every scoped item is implemented, reviewed, verified, committed, merged back, and the backlog file has been archived.

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
- Before raising any notable blocker, missing product decision, failed acceptance, risky ambiguity, or inability to proceed to the user, consult the oracle/smart agent for a second opinion on whether the blocker is real and whether there is a safe implementation path. If the oracle/smart agent confirms or cannot resolve it, explicitly report it as a human-required blocker.

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
3. Mark the backlog item complete only when every acceptance criterion is implemented, reviewed, and verified.
4. If any required acceptance is not done, leave the item open and state exactly what remains.
5. Merge completed work back to local main when the scoped item or safe batch is complete.
6. Clean up the temporary worktree/subtree after merge.
7. If all scoped backlog items are complete, verified, committed, merged back, and reviewed, archive the backlog file according to existing repo conventions.

## BLOCKED pass

Use `BLOCKED` only after exhausting repository context and consulting the oracle/smart agent for a second opinion.

When blocked:

- Do not mark the item complete.
- Commit only if the committed state is coherent and useful; otherwise leave the worktree uncommitted and explain why.
- State the exact missing decision, unavailable dependency, failed acceptance criterion, or unsafe ambiguity.
- Leave `NEXT CONTEXT REQUIRED` with the blocked item as the next target.

## Verification

- Use the smallest targeted verification loop that proves the change or review finding: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- Re-run targeted verification after fixes.
- Do not claim project-wide health unless project-wide checks were actually run.
- Formatting, linting, and broad validation happen once at the end unless needed earlier to unblock work.

## Finish

Commit behavior:

- Commit only task-related work.
- Use concise commit messages.
- Do not include unrelated preserved user work.
- Do not push unless explicitly instructed.

Final response must start with exactly one status line:

`NEXT CONTEXT REQUIRED`

or

`BACKLOG COMPLETE AND ARCHIVED`

Then report:

- backlog file and item ID/title processed
- pass state completed: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- commits made
- verification run
- review result, including correctness/security/performance/design findings
- most likely 3-month breakage reason and whether to address it now or later
- archive location if applicable
- exact next item and state for the next pass, if any
- copy-pasteable next prompt that invokes this command with the backlog file, item, and commit/files to inspect when relevant
- remaining blockers, risks, or product decisions
