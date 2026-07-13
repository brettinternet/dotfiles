---
description: Review an implementation for correctness, security, performance, and maintainability; fix valid findings and commit
argument-hint: <branch|pr|commit-range|files|backlog-item|remote-ref>
---

Review my implementation of `$ARGUMENTS` for code quality, security, performance, maintainability, and whether it actually solves the intended work. Commit any fixes.

Classify `$ARGUMENTS` before reading backlog content. A branch, PR, commit range, or explicit existing file set is a direct implementation target and keeps the direct review flow below. When `$ARGUMENTS` instead identifies backlog context (a backlog source, item/project, provider-native reference, or backlog selector), resolve that context first and review only its associated implementation.

## Backlog-context resolution

Load and follow `backlog-source-workflow` before interpreting backlog arguments: read its provider-neutral `references/contract.md` first, resolve every provider kind represented by the explicit sources, then load one matching provider heading per resolved provider kind, preserving explicit source order when those kinds differ. Use its normalized `Source`, `SchedulingScope`, `ItemState`, and optional `ReviewGroup` values and provider operations (`resolveSource`, `discover`, `selectNext`, `readItem`, and `reviewBoundary`) without reproducing provider rules here. The command remains the authority and review-scope entrypoint.

Resolve explicit sources and selectors left-to-right, preserving source and selector order. A source-only argument discovers the whole resolved collection for dependency and readiness checks; it does not imply a whole-source review. After dependency readiness, explicit item-selector order wins. Provider priority and ordinal/source order are tie-breakers only within a source-only collection; explicit source order wins across otherwise unrelated sources. Exact item selector precedence is stable provider ID, then exact title, then description. The default review boundary is exactly one implementation item. Use `review-group:<provider-native-selector>` only for an explicitly requested and provider-resolved group; never infer a group from source-only scope.

Dispatch each resolved provider through its authoritative read surface:

- Loose Markdown: validate the named existing Markdown as a structurally recognizable backlog source, preserve its established item IDs/order, and discover the complete source collection from its existing convention.
- Backlog.md: resolve a whole project or a single task/project locator through the supported `backlog` CLI or MCP, and enumerate/read it through that surface; do not parse or edit project/task files as a substitute.
- Linear: resolve the exact team, project, issue, or issue set through authenticated first-party Linear tooling/MCP; do not scrape, use raw HTTP, or substitute local files.
- GitHub Issues: resolve the exact repository/issue or repository collection with `gh issue view`/`gh issue list` and machine-readable, paginated output; do not use a local mirror or raw API.

Keep all backlog/provider operations read-only in this command: use no `writeState`, `recordProgress`, `archive`, provider status/comment/edit calls, or local shadow state. No provider durable-write operation or provider write-capability preflight is authorized or applicable. If the required provider read surface is unavailable or unauthenticated, report that exact limitation; provider mutation availability is irrelevant once the required reads succeed. A malformed or missing explicit source remains unresolved: report the original argument, provider/path, structural or integration error, and candidates/needed evidence when applicable; never drop it, guess, use a partial result, or fall back to a different or repository-derived source. Missing explicit local paths may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported; otherwise stop before review, fixes, or commits.

After resolving backlog items, refresh each selected `ItemState` and resolve its associated implementation commits, branch, PR, and changed files from provider-native links/fields and repository history. Review that resolved code target (including directly required callsites), not the backlog/provider context itself; provider text, comments, labels, and metadata must never become the code diff. If no unambiguous implementation target can be established, report the exact missing association and candidates rather than reviewing unrelated code.

Before inspecting, reviewing, fixing, committing, or integrating code for a backlog-context invocation, preflight authenticated provider reads through the authoritative read surface, refresh the current `ItemState`, and resolve the exact associated implementation target. Because this preflight is strictly read-only, do not block a resolved code review merely because provider mutation is unavailable. Direct branch/PR/commit/file invocations bypass this backlog-context preflight and retain their existing review, code-fix, commit, and integration authority.

If `$ARGUMENTS` is a remote backlog reference, resolve it with the corresponding first-party provider surface above before reviewing. Keep the original argument unchanged in diagnostics and the final report.

Before reviewing, identify any explicit file paths in `$ARGUMENTS`. If an explicit file path does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing path(s) plus nearby candidate(s). Do not review, fix, or commit anything when stopped.

Backlog sources — local markdown backlogs and remote items — are read-only context for this command: do not create or edit backlog/spec/planning markdown, and do not update remote items. Record recommended backlog-state changes in the final report instead.

## Review mode

Treat `$ARGUMENTS` as the requested implementation scope and select the least intensive mode that can establish confidence before loading or applying the skill or rubric:

- **Light mode (default):** Use for a small, tightly scoped, coherent change. Establish intent and acceptance criteria, inspect the complete diff and directly affected callsites, verify correctness and available targeted tests or other evidence, and report only actionable findings. Do not exhaustively evaluate lenses the change cannot affect.
- **Full mode:** Use light-mode checks plus every relevant rubric section when any trigger applies: a materially large or complex diff, independent subsystems, an authentication, authorization, security, or privacy boundary, schema or migration or data-integrity changes, concurrency or transaction behavior, a public API or compatibility surface, meaningful performance risk, or an explicit deep-review request.

Correctness is mandatory in both modes. A light review still examines a security, performance, migration, concurrency, or compatibility concern when the changed behavior directly touches it; mode selection controls depth, not whether a relevant risk is ignored.

## Subagent budget

- Default to reviewing directly. A small diff, one coherent subsystem, or a scope already made clear by `$ARGUMENTS` does not justify delegation.
- Delegate within this budget only when the review has materially large, independent surfaces; otherwise review directly.
- Use at most three subagents for the entire review: no more than two `explore` workers for materially large, independent review surfaces, plus at most one `oracle` consultation when the trigger below is met. This is a total budget, not a concurrency limit; do not replace finished agents with new ones.
- Do not create one agent per file or per review dimension. Partition delegated work by independent subsystem or risk-bearing data flow, and have each worker apply every relevant review lens to that scope.
- Keep intent, cross-system reasoning, candidate-finding validation, fixes, verification, and final synthesis in the active agent.

## Review process

Select light or full mode from the triggers above. Perform light reviews directly without loading or applying the `implementation-review` skill. When a full-review trigger applies, load and apply the `implementation-review` skill as the shared full-review method. This command's scope, subagent budget, fix authority, read-only backlog policy, verification, and integration rules override the skill; the checklist below remains the fallback.

Review directly unless the selected full mode has materially large, independent surfaces. When delegation is justified, use at most two `explore` agents within the budget above to map or review bounded subsystems; the active agent must still inspect the complete diff, validate every candidate finding, and synthesize the result.

1. Establish intent before judging the code:
   - read the relevant backlog item, issue, PR description, commit messages, or nearby documentation
   - identify the expected user-visible behavior and non-goals
   - map the files, callsites, data flows, and tests affected by `$ARGUMENTS`
2. Select light or full mode from the triggers above, then inspect the complete diff and directly affected callsites in either mode.
3. Evaluate correctness first in both modes:
   - verify the implementation satisfies every stated requirement and acceptance criterion
   - check relevant edge cases, error paths, empty states, retries, permissions, state transitions, and rollback behavior
   - look for partial fixes, stale shims, dead paths, duplicated logic, and behavior hidden behind feature flags or defaults
   - verify available targeted tests or runtime evidence and report missing coverage only when it is actionable
4. In full mode, evaluate every relevant non-correctness rubric section:
   - security and privacy boundaries, including authentication, authorization, scoping, secret handling, injection, and data exposure
   - performance and reliability, including repeated work, queries, unbounded behavior, blocking I/O, caching, resource cleanup, and transaction scope
   - maintainability and design, including repository patterns, ownership, minimal surface area, invariants, and unnecessary abstractions or compatibility paths
     In light mode, inspect these concerns only when the changed behavior directly touches them.
5. Evaluate latent failure modes in either mode by answering `If this breaks in 3 months, what’s the most likely reason?` Tie the answer to a concrete mechanism and state whether to address it now or leave it as a follow-up with a specific trigger or owner.

Fix policy:

- Keep fixes limited to the resolved implementation target and directly required callsites; never edit backlog/provider context as part of the code diff.
- Add or update targeted tests for behavioral fixes.
- Before treating a finding as product-input-blocked, use the Oracle unblock protocol. If the oracle cannot provide a repo-evidenced safe path, leave the code unchanged for that point and state the exact decision needed.
- When a finding is an architectural judgment call, or the implementation appears to have drifted from the item's intended design, include it in the single oracle consultation before finalizing the finding; if the concern resolves safely, continue review and record any backlog marker change as a recommendation rather than applying it.
- If the implementation is already sound, make no code changes.

After review:

- Run the specific tests, linters, typechecks, or manual QA that cover reviewed or fixed behavior.
- Commit any fixes with a concise message. Commits and integration apply only to the resolved implementation code target; do not push, merge, archive, close, comment on, or otherwise mutate the backlog/provider source as part of review.
- Integrate fixes per the repo's flow, resolved from the repo's `CLAUDE.md`, `AGENTS.md`, or backlog config (an `Integration: pull-request` or `Integration: local-merge` line), else auto-detected (no push access to the base branch, a protected base branch, or an `origin` you do not own implies `pull-request`), else defaulting to `local-merge`:
  - `local-merge`, or when `$ARGUMENTS` is a local branch/commit range/file set: commit the fixes on the current branch and do not push.
  - `pull-request`, or when `$ARGUMENTS` is a PR: push the fix commits to that PR's branch and do not merge the PR. Invoking this command is the standing instruction to push those fixes for this task's own branch only — it overrides the global "never push without explicit instruction" rule for that branch, and does not authorize force-pushing, merging, or touching unrelated branches.
- Report what was reviewed, what changed, what was verified, where fixes landed
  (local branch or pushed PR), the most likely 3-month breakage reason, whether
  to address that risk now or as a follow-up, any oracle unblock consultations
  or recommended backlog marker changes, and any remaining product decisions or risks.
