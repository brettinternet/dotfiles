---
description: Review an implementation proportionately, fix valid findings, verify, and commit
argument-hint: <branch|pr|commit-range|files|backlog-source-or-item> [review-group:<provider-native-selector>]
---

Review the implementation identified by `$ARGUMENTS`, fix valid findings, run targeted verification, and commit the fixes. This command owns target resolution, review depth, fix authority, verification, commits, integration, and output. The `implementation-review` skill supplies only the reusable full-review method and grants no authority.

## Resolve the implementation target

Classify `$ARGUMENTS` before review:

- A branch, PR, commit range, or explicit existing file set is a direct implementation target.
- A backlog source, provider-native item/project reference, or backlog selector is read-only intent context. Load `backlog-source-workflow`: read its provider-neutral contract first, resolve explicit provider kinds in supplied source order, then load one matching provider heading per resolved kind. Use `Source`, `SchedulingScope`, `ItemState`, and optional `ReviewGroup` plus read-only resolution, discovery, item refresh, and review-boundary operations. Do not reproduce provider rules here.

Preserve explicit source and selector order. Source-only backlog context discovers the whole collection for readiness but never implies source-wide review. The default review boundary is one implementation item; accept `review-group:<provider-native-selector>` only when explicitly supplied and provider-resolved. Keep every provider operation read-only: do not edit backlog specifications, write progress/review markers, change status, comment, close, or archive. Provider mutation availability is irrelevant once authenticated reads succeed.

For backlog context, refresh every selected `ItemState` and resolve one exact associated implementation target—commits, branch, PR, commit range, and changed files—from provider-native links/fields, durable markers, and repository history. Review that code and directly required callsites, never provider text/comments/labels/metadata. Stop before review or fixes when the association is missing or ambiguous. Direct implementation targets bypass provider resolution.

Validate explicit file paths before review. A missing path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported; otherwise stop without reviewing, fixing, or committing. Never fall back from an unresolved explicit source or target to unrelated code.

## Choose review depth

Always establish intent and acceptance criteria, inspect the complete target and affected callsites, verify correctness, inspect relevant errors and edge states, and check targeted tests/runtime evidence.

- **Light mode (default):** for a small, tightly scoped, coherent change, perform those checks directly without loading `implementation-review`. Inspect additional security, performance, migration, concurrency, or compatibility concerns only when the changed behavior touches them.
- **Full mode:** load and apply `implementation-review` when the target is materially large or complex, spans independent subsystems or risk-bearing data flows, crosses authentication/authorization/security/privacy, changes schema/migration/data integrity, changes concurrency/transactions, affects public API/compatibility, carries meaningful performance risk, or explicitly requests deep review.

Correctness is mandatory in both modes. Report only actionable findings with a concrete mechanism, affected behavior, location, smallest source-level correction, and behavioral verification. Do not manufacture findings.

## Review execution

Review directly by default. Delegate only materially large independent surfaces, using at most two `explore` agents partitioned by subsystem or risk-bearing data flow; retain complete-diff, cross-system, finding-validation, fix, and synthesis responsibility in the active agent. Use at most one read-only oracle consultation for consequential architecture, design, security, product, ownership, or blocker judgments after gathering evidence.

For every review:

1. Establish expected behavior, acceptance criteria, non-goals, compatibility constraints, affected callsites, data flows, and tests.
2. Inspect the complete implementation target and verify every applicable requirement.
3. Validate candidate findings against current code, intent, repository conventions, guards, tests, and a plausible triggering state.
4. Fix valid issues at the source within the resolved implementation target and directly required callsites; never mutate backlog/provider context.
5. Add or update targeted behavioral tests for fixes and rerun the specific tests, linters, typechecks, or manual QA that cover reviewed behavior.
6. Answer: `If this breaks in 3 months, what is the most likely reason?` Tie it to a concrete mechanism and state whether to address it now or at a named trigger.

If a finding requires unresolved product input, leave that point unchanged and state the exact decision needed. If the implementation is already sound, make no code changes.

## Commit and integration

Commit valid fixes with a concise message. Resolve integration from repository `CLAUDE.md`, `AGENTS.md`, or configuration; otherwise use pull-request flow for a protected/shared remote or PR target and local commit flow for a local branch/commit range/file set.

- For local targets, commit fixes on the current isolated branch/worktree and do not push unless repository flow authorizes it.
- For a PR, push fixes only to that PR branch; do not merge or force-push.
- Never push, merge, archive, close, comment on, or otherwise mutate the backlog/provider source.

Report the resolved implementation target, light/full mode, findings and fixes, verification, commit/integration result, most likely three-month failure mechanism, oracle consultation when used, recommended backlog-state changes, and remaining product decisions or risks.
