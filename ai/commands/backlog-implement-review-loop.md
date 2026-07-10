---
description: Run one backlog task per implementation pass, then review the accumulated item once when implementation is complete
argument-hint: <backlog-files|remote-refs> [item-ids|titles|ranges]
---

Run one pass of the backlog implementation/review loop for `$ARGUMENTS`, commit any task-related change, and leave a concise handoff for the next pass.

This command uses two ordered phases for each backlog item:

1. `IMPLEMENT` — complete exactly one next coherent task within the current backlog item, verify it, and commit it. Repeat implementation passes until the item has no unfinished tasks.
2. `REVIEW` — after the item's implementation sweep is complete, review the entire accumulated implementation together, fix and verify findings, then record a review marker for the exact reviewed commit state.

Treat `$ARGUMENTS` as the exact local backlog file, ordered list of local backlog files, or remote backlog references such as Linear project/issue IDs, plus optional item IDs, titles, or ranges to work through. Do not implement or review unrelated backlog items.

Do not alternate every implementation pass with a review pass. While implementation tasks remain, the next pass implements the next task. Run one item-level `REVIEW` only after all tasks are implemented. Already-implemented unreviewed items may be reviewed together in one batch when that is safe.

## Loop driver

This is a handoff-style loop, not a forever-running process. A single pass ends by telling the next agent what to do:

- after implementing, verifying, and committing one task, hand off the next unfinished task in the same backlog item without reviewing yet
- when no implementation task remains in the item, hand off one `REVIEW` pass over all work accumulated for that item, not one review per task or commit
- fix, verify, and commit review findings in that review pass; do not schedule another pass solely to review its review-fix commit
- when multiple scoped items are already fully implemented but unreviewed, review them together and write their item-local markers in a single batch pass when safe
- after `ARCHIVE`, stop only when the final status is `BACKLOG COMPLETE AND ARCHIVED`

Do not assume prior chat. Start by finding the next unfinished task within the first unfinished scoped backlog item. Select `REVIEW` only when that item has no implementation task left but lacks a valid marker for its accumulated implementation.

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

Determine exactly one current implementation task or one completed implementation review batch:

1. Inspect the current worktree status, preserve unrelated unstaged or untracked work, and do not block on unrelated dirty changes unless they prevent safe isolation; document ignored unrelated changes in the handoff.
2. Read the resolved backlog source or sources in the order supplied, including matching item text, explicit tasks, acceptance criteria, nearby backlog context, remote-source snapshots and remote item marker comments if present, and any existing implementation, review, or blocker notes.
3. Identify the first scoped resolved backlog source, then the first scoped item in that source, that is still open, incomplete, unreviewed, or blocked without a still-valid blocker marker.
4. Within an item needing implementation, select exactly its first explicit open task. When the item has no explicit task list, treat its first unmet acceptance criterion as the next task and select the smallest coherent slice that completes that criterion; repeat on later `IMPLEMENT` passes until no acceptance criterion remains unmet. Never infer that the implementation sweep is complete from finishing only one criterion or slice.
5. Skip an item with a valid `blocked:` marker only when its unblock condition is still unmet and the evidence has not changed. Record the skip in the handoff and continue to the next scoped item in order.
6. Determine the pass state:
   - `IMPLEMENT` when the current item has an identified task whose required behavior is absent, incomplete, failing item-scoped verification, or not traceable to a commit. Complete exactly that first task, verify it, and commit it. Do not review while any implementation task remains in that item.
   - `REVIEW` when the current item has no unfinished explicit task, or when it has no task list and every acceptance criterion is implemented; its behavior has implementation commits or changed files to inspect; and it lacks a valid review marker for that exact accumulated state. Review the entire item implementation together. To avoid extra loops, include other fully implemented-but-unreviewed scoped items in the same pass when they can be reviewed safely as one batch.
   - `BLOCKED` only when a required product decision, unavailable dependency, or unsafe ambiguity prevents both implementation and review and no valid blocker marker already records the same blocker. In-scope verification failures, missing required code, and flaky or outdated tests are not blockers unless they depend on such external input; unrelated failures or dirty changes are ignored and reported separately.
7. If multiple files or items are explicitly requested, preserve the supplied backlog file order. An `IMPLEMENT` pass completes only one task in the current item; a `REVIEW` pass covers the current item's complete accumulated implementation and may batch other fully implemented unreviewed items whose acceptance criteria and verification can be completed safely in the same pass.

Do not skip an open task because a later task, item, or backlog file looks easier. If the next task is oversized, split only its execution plan into the smallest coherent, verifiable slice; do not silently shrink acceptance.

## Handoff contract

At the end of every pass, write the next step clearly enough for another agent to continue:

- current resolved backlog source, item ID/title, and task implemented, or all items in the review batch
- ordered backlog source list and resolution map, when more than one source was supplied
- state to run next: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- implementation commit(s), review-fix commit(s), exact review target commit state, and changed files to inspect or inspected
- acceptance criteria and completed tasks already verified
- verification commands already run and exact results
- remaining tasks and acceptance criteria, unreviewed completed items, risks, blockers, product decisions, ignored unrelated failures or dirty changes, and any blocked items skipped this pass
- oracle consultations used for blockers, accepted or rejected recommendations, and item-local marker changes
- exact next backlog source, item, task or review batch, and command invocation to start from

Use `NEXT CONTEXT REQUIRED` whenever any scoped backlog work remains open, blocked, unreviewed, not integrated, or any writable local markdown backlog file remains unarchived when archiving is required. Use `BACKLOG COMPLETE AND ARCHIVED` only when every scoped item across every supplied source is implemented, reviewed, verified, committed, integrated (merged locally or PR opened), each writable local markdown backlog file has been archived, and each remote-only item is marked done or merged through the first-party tool or its skipped status update is reported.

## Review markers

To avoid reviewing the same work repeatedly, record a review marker only after the item-level `REVIEW` pass verifies the item's entire accumulated implementation and every acceptance criterion, and either makes no changes or verifies all review fixes. A single batch review pass may write a separate marker for every clean, fully implemented item it covers.

For writable backlog sources, store the marker inside the item’s existing notes, status, or conclusion area. Follow the backlog file’s existing style; if there is no style, add one concise item-local line:

`reviewed: <implementation-commit(s)> [review-fix: <commit>]; verified: <brief command/result>`

For remote-only items, do not create local markdown solely to store review state. Post the marker line as a comment on the remote item when the first-party tool supports comments; otherwise record the same marker text in the handoff/final response and use that marker-equivalent handoff state for the next pass.

A review marker — in a writable backlog source, a remote item comment, or marker-equivalent handoff state — is valid only for the exact accumulated implementation commit or commits it names, plus the review-fix commit when present. If any implementation commit changes, the review-fix commit changes, acceptance criteria change, or relevant files change without an updated marker, treat that item as `REVIEW` again after its implementation sweep is complete. Mark the item complete only when all tasks and acceptance criteria are done and that final exact commit state has a valid marker.

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

1. Run the smallest targeted verification loop that proves the completed task: specific tests, typecheck, lint, build, migration check, browser QA, or manual scenario as appropriate.
2. Record the completed task in the writable backlog source using its existing checkbox or status style, then commit only the task-related implementation and task-state changes with a concise message. For remote-only items, preserve the completed-task state in the handoff without editing remote item content. Capture the exact resulting implementation commit and add it to the accumulated item review target.
3. If another implementation task remains in the item, leave the next state as `IMPLEMENT` with that exact task. Do not run or hand off a review between tasks.
4. Leave the next state as `REVIEW` only when no explicit task remains unfinished, or when the item has no task list and every acceptance criterion is implemented. Include every implementation commit, changed file, acceptance criterion, and verification result accumulated for the item.

## REVIEW pass

Use this path only after the current item's implementation sweep is complete. Review its entire accumulated implementation together. When multiple scoped items are already fully implemented but unreviewed, include all safely batchable items in this single pass to avoid one review loop per item.

Review process:

Fan out explore agents to map files, callsites, and data flows, and cheap finder subagents per dimension (correctness, security, performance, maintainability) to surface candidate findings; judge, verify, and synthesize the findings in the orchestrating context. Review the complete accumulated diff for every item in the batch, not each task or commit separately.

1. Establish intent before judging the code:
   - read every backlog item in the review batch, relevant issue or PR descriptions, commit messages, and nearby documentation
   - identify expected user-visible behavior and non-goals for each item
   - map the files, callsites, data flows, tests, and shared interfaces affected by the accumulated implementation
2. Evaluate correctness first:
   - verify every stated or implied acceptance criterion for every item in the review batch
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
- Hard anti-blocking rule: failed checks, item-scoped verification failures, missing required code, and flaky or outdated tests caused by or required for the reviewed implementation are review-fix work to resolve immediately in this same pass. Fix them in-repo, update code/tests/fixtures/config as needed, and rerun targeted verification; unrelated failures or dirty changes may be ignored only after recording why they are unrelated to `$ARGUMENTS`; stop only for a truly external product decision, unavailable dependency, or unsafe ambiguity after exhausting repo fixes and the oracle check.
- Keep fixes limited to `$ARGUMENTS` and directly required callsites.
- Add or update targeted tests for behavioral fixes.
- If a finding needs product input, leave the code unchanged for that point and state the exact decision needed.
- When a finding is an architectural judgment call, or the accumulated implementation appears to have drifted from the item's intended design, consult the oracle agent for a second opinion before finalizing that finding.
- If the reviewed implementation is already sound, make no code changes.

After review:

1. Run the specific tests, linters, typechecks, or manual QA that cover all accumulated reviewed or fixed behavior.
2. Commit any review fixes with a concise message, then treat that verified review-fix commit as covered by this same review pass. Do not schedule another review pass solely because the review changed code.
3. Write or update a separate item-local `reviewed:` marker for every clean item, naming all implementation commits relevant to that item and any review-fix commit. For remote-only items, post the marker as a remote item comment when the tool supports comments, otherwise record the marker-equivalent state in the handoff/final response.
4. Commit writable backlog review-marker and completion-state changes in one concise task-state commit before integration. This state-only commit is not an implementation or review-fix commit and does not invalidate the exact marker it records.
5. Mark a backlog item complete only when all its tasks and acceptance criteria are done, its final exact implementation state has a valid review marker, and any writable marker or completion state is committed.
6. If substantial required implementation remains after review and cannot be completed as a review fix, leave the affected item open, state exactly what remains, and hand off its next exact task as `IMPLEMENT`. Otherwise hand off the first task in the next scoped item.
7. Integrate completed work using the resolved flow (see Integration) when the scoped item or safe batch is complete.
8. Clean up the temporary worktree/subtree after integration; keep the pushed branch under `pull-request`.
9. If all scoped backlog items across all supplied sources are complete, verified, committed, integrated, and reviewed, archive each writable local markdown backlog file according to existing repo conventions and mark each remote-only item done or merged through the first-party tool; when the tool cannot express that status, skip the update and report it.

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

- backlog source list, resolved backlog source list (local markdown files or pinned remote snapshots), item ID/title, and task implemented or review batch processed
- pass state completed: `IMPLEMENT`, `REVIEW`, `BLOCKED`, or `ARCHIVE`
- implementation and review-fix commits made, plus the accumulated commit state reviewed when applicable
- integration result: local merge or PR URL, when the scoped item or batch was integrated this pass
- verification run
- review result over the full accumulated item or batch diff, including correctness/security/performance/design findings and markers written
- most likely 3-month breakage reason and whether to address it now or later
- archive location if applicable; for remote-only sources, the remote status transition applied or skipped
- exact next task and item for `IMPLEMENT`, or accumulated batch target for `REVIEW`, if any
- copy-pasteable next prompt that invokes this command with the backlog file, item, task, and accumulated commits/files when relevant
- remaining blockers, skipped blocked items, risks, product decisions, or ignored unrelated failures or dirty changes
- oracle unblock consultations and item-local marker updates
