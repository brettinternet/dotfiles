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

Before creating a worktree/subtree, reviewing, or editing anything, identify every explicit local backlog file path, remote backlog reference, backlog item selector, and any other explicit file paths in `$ARGUMENTS` (do not treat backlog item IDs, titles, or ranges as paths unless they are explicitly path-shaped). Validate listed local backlog files left-to-right before editing any of them. If a listed local backlog file does not exist, check for nearby existing paths only in path-like locations: the same directory or the same basename after a directory move/rename. Auto-substitute only when exactly one candidate is unambiguous and clearly adjacent; report the substitution to the user. Otherwise stop immediately and report the missing backlog path plus nearby candidate(s). Do not implement, review, fix, or commit anything when the required backlog source cannot be resolved.

The required target is the resolved backlog source plus the requested backlog item when `$ARGUMENTS` scopes one. Find those with loose location matching: adjacent moved/renamed backlog files are acceptable only when unambiguous, and item IDs, titles, or ranges may be matched within the resolved backlog text. Other explicit file paths in `$ARGUMENTS` are discovery hints for relevant implementation or review files, not presence gates. Try to find them by exact path first, then nearby path-like locations or repository search when useful; report unresolved hint paths in the handoff, but do not stop solely because a non-backlog file hint is absent.

## Backlog storage policy

Derive storage behavior per resolved backlog source from repository context:

- a local markdown backlog file named in `$ARGUMENTS` is a writable backlog source
- a remote item makes an existing local backlog entry writable only when exactly one repo markdown file matches it structurally as a backlog — an item list or item headings carrying the item's ID — not merely any file that mentions the ID
- every other remote item is remote-only: never write repo backlog/spec/planning markdown for it

Never create new backlog/spec/planning markdown unless the repo already demonstrates that exact convention, such as existing snapshot or spec files matching remote item IDs. When in doubt, do not create files; write only to writable backlog sources. Moving or renaming an existing backlog file into the repo's archive location per repo convention is an edit to an existing source, not creation.

## Remote backlog sources

Remote backlog references, such as Linear project identifiers, issue IDs, or issue URLs, are discovery inputs only. Do not run the implementation loop directly against a moving remote source.

Invoking this command with remote backlog references is the standing authorization to write loop state back to those exact remote items through the first-party tool: mark an item done or merged when its work is integrated, and post `reviewed:`/`blocked:` marker lines as item comments when the tool supports comments. It does not authorize editing remote item content otherwise, creating or deleting remote items, or touching items outside `$ARGUMENTS`.

Before implementation or review:

1. Resolve each remote reference using the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Fetch the exact remote items in the order implied by `$ARGUMENTS`, including their existing marker comments.
3. Pin each remote item into an exact resolved backlog source: its writable local backlog entry when one exists, a new snapshot file only when the repo's creation convention permits it, otherwise handoff notes, command-local notes, or a temporary file outside the worktree.
4. Apply code edits against that pinned text, not the moving remote source. If the remote item changes later, refresh the pinned source first, then re-evaluate review and blocker state against the new pinned text.
5. Record `reviewed:` and `blocked:` markers in the item's writable backlog source; for remote-only items, post the marker line as a comment on the remote item when the first-party tool supports comments, otherwise record the marker-equivalent state in the handoff.

Local repo markdown backlogs remain first-class inputs. When `$ARGUMENTS` names local markdown backlog files, use them directly after path validation and modify, complete, or archive them following their existing style. Local markdown that is not a writable backlog source is read-only context.

## Target selection

Determine exactly one current target:

1. Inspect the current worktree status, preserve unrelated unstaged or untracked work, and do not block on unrelated dirty changes unless they prevent safe isolation; document ignored unrelated changes in the handoff.
2. Read the resolved backlog source or sources in the order supplied, including matching item text, acceptance criteria, nearby backlog context, remote-source snapshots and remote item marker comments if present, and any existing implementation, review, or blocker notes.
3. Identify the first scoped resolved backlog source, then the first scoped item in that source, that is still open, incomplete, unreviewed, or blocked without a still-valid blocker marker.
4. Skip an item with a valid `blocked:` marker only when its unblock condition is still unmet and the evidence has not changed. Record the skip in the handoff and continue to the next scoped item in order.
5. Determine the pass state:
   - `IMPLEMENT` when required behavior is absent, incomplete, failing item-scoped verification, or not traceable to a commit.
   - `REVIEW` when the behavior appears implemented, has an implementation commit or changed files to inspect, and lacks a valid review marker for that exact implementation.
   - `BLOCKED` only when a required product decision, unavailable dependency, or unsafe ambiguity prevents both implementation and review and no valid blocker marker already records the same blocker. In-scope verification failures, missing required code, and flaky or outdated tests are not blockers unless they depend on such external input; unrelated failures or dirty changes are ignored and reported separately.
6. If multiple files or items are explicitly requested, preserve the supplied backlog file order and process only the smallest safe batch whose acceptance criteria and verification can be completed in this pass. Leave the next exact file and item in the handoff.

Do not skip an open item because a later item or later backlog file looks easier. If the next item is oversized, split only the execution plan; do not silently shrink acceptance.

## Handoff contract

At the end of every pass, write the next step clearly enough for another agent to continue:

- current resolved backlog source and item ID/title
- ordered backlog source list and resolution map, when more than one source was supplied
- state to run next: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- implementation commit(s), review-fix commit(s), or changed files to inspect
- acceptance criteria already verified
- verification commands already run and exact results
- remaining acceptance criteria, risks, blockers, product decisions, ignored unrelated failures or dirty changes, and any blocked items skipped this pass
- oracle consultations used for blockers, accepted or rejected recommendations, and item-local marker changes
- exact next backlog source, item, and command invocation to start from

Use `NEXT CONTEXT REQUIRED` whenever any scoped backlog work remains open, blocked, unreviewed, not integrated, or any writable local markdown backlog file remains unarchived when archiving is required. Use `BACKLOG COMPLETE AND ARCHIVED` only when every scoped item across every supplied source is implemented, reviewed, verified, committed, integrated (merged locally or PR opened), each writable local markdown backlog file has been archived, and each remote-only item is marked done or merged through the first-party tool or its skipped status update is reported.

## Review markers

To avoid reviewing the same implementation repeatedly, record a review marker only after a clean `REVIEW` pass verifies every acceptance criterion and either makes no changes or verifies all review fixes.

For writable backlog sources, store the marker inside the item’s existing notes, status, or conclusion area. Follow the backlog file’s existing style; if there is no style, add one concise item-local line:

`reviewed: <implementation-commit> [review-fix: <commit>]; verified: <brief command/result>`

For remote-only items, do not create local markdown solely to store review state. Post the marker line as a comment on the remote item when the first-party tool supports comments; otherwise record the same marker text in the handoff/final response and use that marker-equivalent handoff state for the next pass.

A review marker — in a writable backlog source, a remote item comment, or marker-equivalent handoff state — is valid only for the exact implementation commit it names, plus the review-fix commit when present. If the implementation commit changes, review-fix commit changes, acceptance criteria change, or relevant files change without an updated marker, treat the item as `REVIEW` again. If the marker is valid and the item is complete, do not re-review it; move to the next unfinished scoped item in the ordered backlog list.

## Blocker markers

To avoid repeating the same blocker forever, record a blocker marker only after exhausting repository context, fixing every in-scope verification failure, missing required code path, and flaky or outdated test, attempting all safe unblocked work, and consulting the oracle agent for a second opinion.

For writable backlog sources, store the marker inside the item’s existing notes, status, or conclusion area. Follow the backlog file’s existing style; if there is no style, add one concise item-local line:

`blocked: <short reason>; tried: <brief attempted path>; unblock: <specific decision/dependency/evidence needed>`

For remote-only items, do not create local markdown solely to store blocker state. Post the `blocked:` line as a comment on the remote item when the first-party tool supports comments; otherwise record the same `blocked:` text in the handoff/final response and move on per `BLOCKED` rules.

A blocker marker — in a writable backlog source, a remote item comment, or marker-equivalent handoff state — is valid only while the reason, attempted path, and unblock condition still match the current code, backlog text, dependencies, and verification evidence. Skip a blocked item only when its marker is still valid. Re-enter it automatically when new information appears, dependencies become available, acceptance criteria change, relevant code changes, or the unblock condition no longer matches; then clear, replace, or supersede the marker where it was recorded, and continue with `IMPLEMENT` or `REVIEW`. If every remaining scoped item is blocked by still-valid markers, stop with `NEXT CONTEXT REQUIRED` and report the blocker list.

## Oracle unblock protocol

The oracle agent is advisory and read-only. It must not edit code, mutate local or remote backlog files, push, commit, or mark an item complete. The active command agent owns every backlog edit and must verify the oracle recommendation against repository/backlog evidence before resuming.

Use this protocol whenever a subagent or pass is blocked by a decision, stale blocker, unsafe ambiguity, or failed acceptance criterion that might be resolvable without human input:

1. Finish all safe unblocked work first, then capture the exact blocker, attempted paths, evidence, affected files, acceptance criteria, and any existing `blocked:` marker.
2. Ask the oracle for exactly one outcome and, when it recommends `RESUME` or `BLOCKED`, an exact item-local patch:
   - `RESUME`: a safe, repo-evidenced decision or implementation path within the current acceptance criteria.
   - `BLOCKED`: the blocker is real; provide the exact item-local `blocked:` marker and unblock condition.
   - `HUMAN_DECISION`: the decision would change product scope, user-visible behavior, data policy, security posture, external dependency terms, or acceptance criteria without first-party evidence.
3. Treat `RESUME` as a proposed patch, not authority. Apply it only if the active agent can point to the backing backlog text, code convention, dependency documentation, or verification evidence. The patch may only clear a stale `blocked:` marker or replace it with an updated `blocked:` marker when the blocker still applies. It must not add a durable oracle/unblock lifecycle state, change acceptance criteria, mark the item reviewed/complete, or modify remote state.
4. After applying or rejecting the patch, re-run Target selection from current backlog text, code, dependencies, and verification evidence. If the prior blocker no longer matches, continue as `IMPLEMENT` or `REVIEW`; otherwise keep/update `blocked:` and move on per `BLOCKED` rules.
5. Record accepted or rejected oracle reasoning in the handoff, not as a selection state. If backlog text, relevant code, dependencies, or verification evidence changes, normal Target selection and blocker-validity rules decide the next state.
6. If the oracle returns `BLOCKED` or `HUMAN_DECISION`, write/update the normal `blocked:` marker in the item's writable backlog source, post it as a remote item comment for remote-only items when the tool supports comments, or record the marker-equivalent state in the handoff.
7. For remote-only items, never write repo markdown for marker state; use the authorized remote comment flow or the handoff marker-equivalent state.

## IMPLEMENT pass

Before editing:

1. Create or switch to an isolated worktree/subtree for the implementation so local user work is not disturbed.
2. Read relevant existing code patterns before designing a new one.
3. Map required callsites, data flows, tests, migrations, and UI/API behavior from the backlog item.
4. Coordinate shared interfaces before parallel edits when tasks touch the same API, schema, type, or command.

Parallelization:

- Fan out subagents and orchestrate executor subagents for independent, well-specified file areas, tests, UI, or migrations.
- Use explore agents for read-only discovery and evidence gathering; keep the orchestrating context for decisions, synthesis, and shared-interface coordination.
- Give each subagent the exact target, scope boundaries, acceptance criteria, and non-goals.
- Do not serialize work that can safely happen in parallel.
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
- Before raising any notable blocker, missing product decision, failed acceptance, risky ambiguity, or inability to proceed to the user, use the Oracle unblock protocol. If the oracle returns a repo-evidenced safe path, apply the verified item-local patch, re-run Target selection, and resume; if it confirms or cannot resolve the blocker, explicitly report it as a human-required blocker.

After implementation:

1. Run the smallest targeted verification loop that proves the change: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
2. Commit only task-related implementation work with a concise message.
3. Do not mark the backlog item complete yet unless the same pass also performs the `REVIEW` gate after the implementation commit.
4. Leave the next state as `REVIEW` with the exact implementation commit(s), files, and verification evidence.

## REVIEW pass

Use this path when the target item appears already implemented, either from a previous pass, existing commits, or current task-related changes.

Review process:

Fan out explore agents to map files, callsites, and data flows, and cheap finder subagents per dimension (correctness, security, performance, maintainability) to surface candidate findings; judge, verify, and synthesize the findings in the orchestrating context.

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
- Hard anti-blocking rule: failed checks, item-scoped verification failures, missing required code, and flaky or outdated tests caused by or required for the current backlog item are review-fix work to resolve immediately. Fix them in-repo, update code/tests/fixtures/config as needed, and rerun targeted verification; unrelated failures or dirty changes may be ignored only after recording why they are unrelated to `$ARGUMENTS`; stop only for a truly external product decision, unavailable dependency, or unsafe ambiguity after exhausting repo fixes and the oracle check.
- Keep fixes limited to `$ARGUMENTS` and directly required callsites.
- Add or update targeted tests for behavioral fixes.
- If a finding needs product input, leave the code unchanged for that point and state the exact decision needed.
- When a finding is an architectural judgment call, or the implementation appears to have drifted from the item's intended design, consult the oracle agent for a second opinion before finalizing that finding.
- If the implementation is already sound, make no code changes.

After review:

1. Run the specific tests, linters, typechecks, or manual QA that cover reviewed or fixed behavior.
2. Commit any review fixes with a concise message.
3. Write or update the item-local `reviewed:` marker in the item's writable backlog source; for remote-only items, post it as a remote item comment when the tool supports comments, otherwise record the marker-equivalent state in the handoff/final response.
4. Mark the backlog item complete only after the valid review marker is present in its writable backlog source, remote item comment, or marker-equivalent handoff state.
5. If any required acceptance is not done, leave the item open and state exactly what remains.
6. Integrate completed work using the resolved flow (see Integration) when the scoped item or safe batch is complete.
7. Clean up the temporary worktree/subtree after integration; keep the pushed branch under `pull-request`.
8. If all scoped backlog items across all supplied sources are complete, verified, committed, integrated, and reviewed, archive each writable local markdown backlog file according to existing repo conventions and mark each remote-only item done or merged through the first-party tool; when the tool cannot express that status, skip the update and report it.

## BLOCKED pass

Use `BLOCKED` only after exhausting repository context, fixing every in-scope verification failure, missing required code path, and flaky or outdated test required by the current item, consulting the oracle agent for a second opinion, and applying the Oracle unblock protocol without finding a safe `RESUME` path.

When blocked:

- Implement and verify any acceptance criteria that are safely unblocked before marking the item blocked; fix in-scope failing checks, missing required code, and flaky or outdated tests instead of recording them as blockers, and report unrelated failures or dirty changes separately.
- Do not mark the item complete.
- Write or update the item-local `blocked:` marker in the item's writable backlog source; for remote-only items, post it as a remote item comment when the tool supports comments, otherwise record the same `blocked:` text in the handoff/final response. Include the exact missing decision, unavailable dependency, failed acceptance criterion plus its external input/dependency root cause, or unsafe ambiguity; include what was tried and the next concrete unblock action.
- Commit only if the committed state is coherent and useful; otherwise leave the worktree uncommitted and explain why.
- Move the next pass to the next scoped item whose blocker marker is absent, stale, or resolved. Do not keep selecting the same still-blocked item.
- Leave `NEXT CONTEXT REQUIRED` with the skipped blocker list and the next unblocked target. If no unblocked target remains, report the human-required blocker queue instead of archiving.

## Verification

- Use the smallest targeted verification loop that proves the change or review finding: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
- Re-run targeted verification after fixes. If verification fails, diagnose the root cause, fix all in-scope code/tests/checks in-repo, and rerun before reporting a blocker; if the failure is unrelated to the current item, record the evidence and continue with targeted verification.
- Unrelated failing tests or unrelated dirty changes do not block finishing the item or reporting it complete; note them separately, and do not fix or commit them as part of this work.
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
- Unrelated failing checks or unrelated dirty changes do not block handoff or completion for a done scoped item; report them as out-of-scope observations only.
- Do not include unrelated preserved user work.
- Do not push unrelated work. Under `pull-request` flow, pushing the task branch and opening its PR is authorized by invoking this command (see Integration); do nothing beyond that branch.

Final response must start with exactly one status line:

`NEXT CONTEXT REQUIRED`

or

`BACKLOG COMPLETE AND ARCHIVED`

Then report:

- backlog source list, resolved backlog source list (local markdown files or pinned remote snapshots), and item ID/title processed
- pass state completed: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- commits made
- integration result: local merge or PR URL, when the scoped item or batch was integrated this pass
- verification run
- review result, including correctness/security/performance/design findings
- most likely 3-month breakage reason and whether to address it now or later
- archive location if applicable; for remote-only sources, the remote status transition applied or skipped
- exact next item and state for the next pass, if any
- copy-pasteable next prompt that invokes this command with the backlog file, item, and commit/files to inspect when relevant
- remaining blockers, skipped blocked items, risks, product decisions, or ignored unrelated failures or dirty changes
- oracle unblock consultations and item-local marker updates
