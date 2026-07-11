---
description: Review an implementation for correctness, security, performance, and maintainability; fix valid findings and commit
argument-hint: <branch|pr|commit-range|files|backlog-item|remote-ref>
---

Review my implementation of `$ARGUMENTS` for code quality, security, performance, maintainability, and whether it actually solves the intended work. Commit any fixes.

Treat `$ARGUMENTS` as the exact implementation, branch, PR, commit range, backlog item, remote backlog reference (such as a Linear issue), or file set to review. Do not review unrelated work except where needed to understand callsites or behavior.

Before reviewing, identify any explicit file paths in `$ARGUMENTS`. If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not review, fix, or commit anything when stopped.

If `$ARGUMENTS` is a remote backlog reference (such as a Linear issue), first resolve it with the available first-party tool (the Linear MCP/tooling for Linear; if none is authenticated, stop and report the missing integration) to the associated PR, branch, commits, or local backlog snapshot, then review that implementation.

Backlog sources — local markdown backlogs and remote items — are read-only context for this command: do not create or edit backlog/spec/planning markdown, and do not update remote items. Record recommended backlog-state changes in the final report instead.

## Subagent budget

- Default to reviewing directly. A small diff, one coherent subsystem, or a scope already made clear by `$ARGUMENTS` does not justify delegation.
- Delegate within this budget only when the review has materially large, independent surfaces; otherwise review directly.
- Use at most three subagents for the entire review: no more than two `explore` workers for materially large, independent review surfaces, plus at most one `oracle` consultation when the trigger below is met. This is a total budget, not a concurrency limit; do not replace finished agents with new ones.
- Do not create one agent per file or per review dimension. Partition delegated work by independent subsystem or risk-bearing data flow, and have each worker apply every relevant review lens to that scope.
- Keep intent, cross-system reasoning, candidate-finding validation, fixes, verification, and final synthesis in the active agent.

## Oracle unblock protocol

The oracle agent is advisory and read-only. It must not edit code, mutate backlog files, push, commit, or decide product scope. When review hits a blocking product decision, unsafe ambiguity, stale blocker, or failed acceptance that may be resolvable, finish safe review work first, then consult the oracle with intent, acceptance criteria, implementation evidence, attempted paths, and the exact decision needed.

Make at most one oracle consultation in the review. Gather repository evidence first and batch related unresolved judgments or blockers; do not consult it for ordinary review findings or as routine confirmation.

Accept an oracle `RESUME` recommendation only when the reviewing agent can verify it from backlog text, existing repo patterns, dependency docs, or test evidence. The oracle may return a proposed item-local patch, but backlog sources are read-only for this command: after verifying the patch, record it in the report or handoff as a recommended marker change instead of applying it. A valid patch may only clear a stale `blocked:` marker or replace it with an updated `blocked:` marker when the blocker still applies. It must not add a durable oracle/unblock lifecycle state, rewrite acceptance criteria, mark the item complete/reviewed, or update remote backlog state. Re-run review state selection from current evidence; if the blocker still matches, keep the `blocked:` recommendation and record the oracle reasoning only in the report or handoff.

Review process:
When available, apply the `implementation-review` skill as the shared review method. This command's scope, subagent budget, fix authority, read-only backlog policy, verification, and integration rules override the skill; the checklist below remains the fallback.

Review directly unless the implementation has materially large, independent surfaces. When delegation is justified, use at most two `explore` agents within the budget above to map or review bounded subsystems; the active agent must still inspect the complete diff, validate every candidate finding, and synthesize the result.

1. Establish intent before judging the code:
   - read the relevant backlog item, issue, PR description, commit messages, or nearby documentation
   - identify the expected user-visible behavior and non-goals
   - map the files, callsites, data flows, and tests affected by `$ARGUMENTS`
2. Evaluate correctness first:
   - verify the implementation satisfies every stated requirement
   - check edge cases, error paths, empty states, retries, concurrency, permissions, migrations, and rollback behavior
   - look for partial fixes, stale shims, dead paths, duplicated logic, and behavior hidden behind feature flags or defaults
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
   - make the answer actionable by tying it to a concrete mechanism: ownership
     drift, unchecked edge case, schema/API change, concurrency, permissions,
     data volume, dependency behavior, missing test coverage, or an unclear
     invariant
   - include whether the risk should be addressed now or left as a follow-up,
     with the reason for that timing

Fix policy:

- Fix valid issues at the source, not by suppressing warnings or narrowing tests.
- Keep fixes limited to `$ARGUMENTS` and directly required callsites.
- Add or update targeted tests for behavioral fixes.
- Before treating a finding as product-input-blocked, use the Oracle unblock protocol. If the oracle cannot provide a repo-evidenced safe path, leave the code unchanged for that point and state the exact decision needed.
- When a finding is an architectural judgment call, or the implementation appears to have drifted from the item's intended design, include it in the single oracle consultation before finalizing the finding; if the concern resolves safely, continue review and record any backlog marker change as a recommendation rather than applying it.
- If the implementation is already sound, make no code changes.

After review:

- Run the specific tests, linters, typechecks, or manual QA that cover reviewed or fixed behavior.
- Commit any fixes with a concise message.
- Integrate fixes per the repo's flow, resolved from the repo's `CLAUDE.md`, `AGENTS.md`, or backlog config (an `Integration: pull-request` or `Integration: local-merge` line), else auto-detected (no push access to the base branch, a protected base branch, or an `origin` you do not own implies `pull-request`), else defaulting to `local-merge`:
  - `local-merge`, or when `$ARGUMENTS` is a local branch/commit range/file set: commit the fixes on the current branch and do not push.
  - `pull-request`, or when `$ARGUMENTS` is a PR: push the fix commits to that PR's branch and do not merge the PR. Invoking this command is the standing instruction to push those fixes for this task's own branch only — it overrides the global "never push without explicit instruction" rule for that branch, and does not authorize force-pushing, merging, or touching unrelated branches.
- Report what was reviewed, what changed, what was verified, where fixes landed
  (local branch or pushed PR), the most likely 3-month breakage reason, whether
  to address that risk now or as a follow-up, any oracle unblock consultations
  or recommended backlog marker changes, and any remaining product decisions or risks.
