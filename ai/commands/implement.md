---
description: Implement the feature described by the user in an isolated worktree, verify independently, commit, and integrate per the repo's flow
argument-hint: <feature-description> [acceptance-criteria|constraints|relevant-files]
---

Implement exactly the feature described in `$ARGUMENTS` in an isolated worktree. Preserve existing unstaged work, use the smallest targeted verification loop, commit only feature-related work, integrate it per the repo's flow (merge to local main or open a PR), and clean up the worktree.

Treat `$ARGUMENTS` as the complete feature request and source of scope. Extract the requested behavior, acceptance criteria, constraints, relevant files, and explicit non-goals from the user's description. Existing code and repository conventions are implementation context, not an additional source of requested work. Do not search for, create, update, complete, or archive backlog/spec/planning items, and do not infer scope from nearby issues or TODOs.

## Feature contract

Before editing:

1. Inspect the current worktree status, preserve unrelated unstaged or untracked work, and do not block on unrelated dirty changes unless they prevent safe isolation; document ignored unrelated changes in the final report.
2. Convert `$ARGUMENTS` into a concrete implementation contract: user-visible behavior, acceptance criteria, constraints, non-goals, and directly affected surfaces. Do not expand the request with retries, telemetry, validation, abstractions, or cleanup that the feature does not require.
3. Read the relevant existing code, callsites, tests, configuration, and repository patterns. Use symbol-aware references before changing exported symbols.
4. Resolve ordinary implementation details from established repository conventions. Carry only a materially different product or architecture choice into the oracle policy below; do not escalate routine implementation choices.
5. Confirm the feature can be completed safely. If it is large, split only the execution plan; do not silently shrink the requested acceptance.
6. Create or switch to an isolated worktree for implementation so local user work is not disturbed.

## Subagent budget

- Default to direct implementation. A small feature, a tightly coupled change, or work in one subsystem does not justify delegation.
- Delegate within this budget only when the feature has materially substantial, independent branches; otherwise implement directly.
- Use at most four subagents for the entire invocation: no more than two `explore` or `executor` workers combined, one final `verifier` when completion is claimed, and at most one `oracle` consultation when an explicit trigger below is met. This is a total budget, not a concurrency limit; do not replace finished agents with new ones.
- Delegate only materially substantial, independent work whose target, acceptance criteria, and non-goals can be specified up front. Use an `explore` agent only when the relevant surface is genuinely unknown or spans independent subsystems; use an `executor` only for a disjoint file area with settled interfaces.
- Keep shared-interface changes, small lookups, decisions, synthesis, and integration in the active agent. The implementer that owns a behavior also owns its tests; do not create a separate test-authoring agent.
- If more work is parallelizable than the budget permits, delegate the highest-risk or highest-latency branches and perform the rest directly. Run formatting, linting, and broad validation once at the end unless a smaller check is needed to unblock implementation.

## Implementation rules

- Implement the real behavior described by `$ARGUMENTS`, not a scaffold, TODO, mock, fake fallback, no-op, or warning suppression.
- Fix requirements at the source and reuse existing repository patterns and shared code where they fit.
- Keep changes limited to the feature and its required callsites, tests, generated artifacts, migrations, configuration, or documentation.
- Delete obsolete code paths made unnecessary by the change. Do not leave compatibility shims, aliases, deprecated paths, or duplicate implementations unless `$ARGUMENTS` explicitly requires them.
- Add or update tests for requested behavior, conditional branches, edge values, invariants, and failure modes implied by the feature.
- When the implementation uses a reusable coding pattern, tell the user `CODE PATTERN:` followed by a brief description, whether it matches an existing repository implementation, and whether code can be shared. If sharing is practical, refactor to use the shared implementation instead of introducing a second convention.
- Failed feature-scoped checks, missing required code, and outdated tests or fixtures caused by the feature are implementation work. Fix them in-repo and rerun targeted verification. Ignore unrelated failures only after recording evidence that they are unrelated.
- If product information is missing, implement everything not blocked and record the exact remaining decision instead of guessing.
- Use the one optional oracle consultation only after gathering repository evidence, and only for consequential, hard-to-reverse design tradeoffs or a possible genuine external blocker. Batch related questions; do not consult for ordinary choices or routine check failures.
- Before reporting a human-required blocker, include the exact blocker, attempted paths, and evidence in that consultation. Report it as human-required only if no safe, repo-evidenced path remains.

## Completion criteria

Treat the feature as complete only when:

- every stated acceptance criterion and behavior directly required for end-to-end correctness is implemented
- every required callsite and affected artifact is updated
- obsolete paths introduced or superseded by the feature are removed
- targeted verification proves the behavior
- the verifier agent independently checks `$ARGUMENTS` against the implementation commits and returns PASS for every criterion
- the feature is committed and integrated using the resolved repository flow

If any required acceptance criterion remains incomplete or unverified, do not claim completion. State exactly what remains and why it requires user input or an unavailable external prerequisite.

## Verification

- Smoke-test the feature as soon as the end-to-end path works. Only after that succeeds, finish tests, documentation required by the feature, formatting, linting, generated artifacts, and removal of temporary scaffolding.
- Use the smallest targeted verification loop that proves the change: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- For web UI changes, verify the behavior in the browser with the Chrome DevTools tooling in addition to targeted automated checks.
- Before marking the feature complete, run the verifier agent with the exact user description, acceptance criteria, implementation commits, and changed files — not the implementer's conclusions — and treat any FAIL or UNVERIFIED criterion as open work.
- Re-run targeted verification after fixes. Diagnose the root cause of feature-scoped failures, fix all in-scope code, tests, fixtures, or configuration, and rerun before reporting a blocker.
- Unrelated failing tests or unrelated dirty changes do not block completion; note them separately and do not fix or commit them as part of this feature.
- Do not claim project-wide health unless project-wide checks were actually run.

## Integration

Resolve the finish flow before pushing, merging, or opening anything:

1. If the repo's `CLAUDE.md`, `AGENTS.md`, or configuration declares a flow (for example, `Integration: pull-request` or `Integration: local-merge`), obey it. For `pull-request`, use the declared base branch (default `main`) and branch prefix if given.
2. Otherwise auto-detect: if you lack push access to the base branch, the base branch is protected, or `origin` is a shared remote you do not own, use `pull-request`.
3. When still ambiguous, default to `local-merge`.

- `local-merge`: merge the completed, verified work back to local `main`; clean up the temporary worktree; do not push.
- `pull-request`: push the feature branch to `origin` and open a PR against the base branch with `gh`, using a concise title and body summarizing the feature and verification; clean up the worktree but keep the pushed branch; do not merge locally and do not merge the PR; report the PR URL and recommend `/pr-babysit [reviewer]` as the follow-up to drive it to green and approval. Invoking this command is the standing instruction to push and open the PR for this feature's own branch only — it overrides the global "never push / never open PRs without explicit instruction" rule for that branch and does not authorize force-pushing, merging, or touching unrelated branches.

## Finish

- Commit only feature-related work with a concise message.
- Integrate the completed work using the resolved flow above.
- Start the final report with exactly one status line:
  - `IMPLEMENTATION COMPLETE` only when every acceptance criterion is implemented, verified, committed, and integrated.
  - `IMPLEMENTATION BLOCKED` when any required acceptance criterion, verification, external prerequisite, or product decision remains incomplete.
- Then report the implemented feature, changed behavior, commits made, verification run, verifier result, integration result (local merge or PR URL), `CODE PATTERN:` when applicable, ignored unrelated failures or dirty changes, and any remaining blocker or product decision.
