---
description: Babysit a PR — keep CI green, address PR feedback, request a reviewer, then work their feedback until they approve
argument-hint: [pr-number] [reviewer]
---

Babysit a pull request through to ready-to-merge.

Parse `$ARGUMENTS` to decide the PR and reviewer instead of relying on fixed
positions:

- Any token that is only digits, or `#` followed by digits, is the PR number.
- Any non-PR token is the reviewer to request; strip one leading `@` if present.
  After stripping, the reviewer must be non-empty; reject a lone `@` and print
  the usage.
- If there is no PR number, enter batch mode: discover every open PR authored by
  the authenticated GitHub user in this repository and babysit them in parallel.
- If there is no reviewer, skip the reviewer-request and reviewer-feedback steps
  and say so for each PR.
- If there is more than one PR-number token, or more than one reviewer token,
  stop and tell the user the usage:
  `/pr-babysit [pr-number] [reviewer]`.

Resolve PR numbers in the current directory's GitHub repo only. Do not accept a
PR URL or `owner/repo#N` shorthand here; using a bare number avoids ambiguity
with the optional reviewer. In batch mode, the authenticated GitHub account
returned by `gh api user --jq .login` is the author filter; do not infer an
author from the current branch or from PR titles.

You are driving this autonomously. Do not stop at the first status check —
loop until the exit condition below is met or you hit a genuine blocker that
needs a human.

This command is repo-agnostic: discover the project's owner/repo, default
branch, validation gate, and test commands from the repo itself (git remote,
`gh repo view`, and any agent/context files like `AGENTS.md` / `CLAUDE.md` /
`CONTRIBUTING.md`). Do not assume a language, build tool, or CI layout.

Batch mode is a real multi-PR orchestration mode, not a loop over one shared
checkout. Active means `state=OPEN`; include open drafts deliberately so no
active PR is silently omitted.

## External communication

Load and apply the `user-voice` skill to everything posted to GitHub:
review-thread and inline-comment replies, top-level PR comments, reviewer-request
summaries, and approval or review-comment bodies. This command grants the
posting authority; the skill controls wording only. Skip trivial nits. Treat
completed-fix, stale-finding, and disagreement replies as declarative replies.
For new feedback directed at the PR author, ask exactly one sincere question
they can answer or push back on. Do not stack questions; for a blocker, ask one
direct question that names the concern.
When posting a new finding, use a file-line review comment whenever it maps to a
line in the current diff; use a top-level review comment only when no specific
changed line fits. Never submit a `REQUEST_CHANGES` review: post a `COMMENT`
review instead, so the author receives the feedback without an explicit block.

## 0. Locate the PR

- Resolve `<owner>/<repo>` from the remote (`gh repo view --json owner,name`)
  before looking up any PR.
- If a PR number was parsed, run
  `gh pr view <n> --json number,title,state,url,reviewDecision,mergeStateStatus,isDraft,headRefName,headRefOid,headRepository`
  in the current repo. If it does not resolve, stop and say the PR number is not
  in this repo.
- For every selected PR, retain `headRepository.nameWithOwner`, `headRefName`,
  and `headRefOid`, then resolve its source push URL with
  `gh repo view <headRepository.nameWithOwner> --json sshUrl --jq .sshUrl`.
  This source URL and branch are the only valid push target in both single and
  batch modes. If `headRepository` is null, stop that PR as blocked.

- If no PR number was parsed, resolve the authenticated author once with
  `gh api user --jq .login`. If authentication fails, stop clearly. Discover
  every open PR without a fixed result cap using:
  ```
  gh api graphql --paginate -f query='query($endCursor:String) {
    repository(owner:"<owner>", name:"<repo>") {
      pullRequests(first:100, states:OPEN, after:$endCursor) {
        nodes { number author { login } }
        pageInfo { hasNextPage endCursor }
      }
    }
  }' --jq '.data.repository.pullRequests.nodes[]
    | select(.author.login == "<login>") | .number'
  ```
  Fetch each candidate with the same `gh pr view` fields above, extract
  `.headRepository.nameWithOwner` from the returned `headRepository` object,
  and retain the source branch and head SHA. If discovery fails, stop and say
  so. If `headRepository` is null (for example, a deleted fork), report that
  PR as blocked rather than guessing a push target. If the list is empty,
  report that the authenticated author has no open PRs in this repo and stop.
- In batch mode, treat every returned `state:OPEN` PR as active, including
  drafts. Do not silently fall back to the current branch when discovery finds
  no PRs.
- In single-PR mode only, confirm local `HEAD` matches the pushed branch tip
  when the selected PR is the current branch's PR
  (`git rev-parse HEAD` vs `git rev-parse @{u}`). If local is ahead, tell the
  user there are unpushed commits and stop — do not push without being asked.
  If `git rev-parse @{u}` fails because no upstream exists, treat the branch as
  unpushed and stop.
- In single mode, do not edit until local `HEAD` equals the selected PR's
  `headRefOid`; otherwise stop and refresh or check out the exact PR head.
- Before any single-mode edit, and before each subsequent fix, re-read the PR
  with `gh pr view` and require `state:OPEN`, the same source repository/ref,
  and the expected `headRefOid`; if any changed, stop and refresh. After this
  command's own push, update the expected SHA to the pushed head before looping.
- Before editing in single mode, require `git status --porcelain` to be empty;
  otherwise stop and report the dirty worktree.

- If a numbered PR is on a different branch than the current branch, do not
  make code changes until the current worktree is clean and that PR head branch
  is checked out locally; otherwise stop and say which branch is needed. Batch
  workers use the detached worktree contract instead.

## Batch orchestration (no PR number)

The parent agent is the coordinator; it does not edit PR code in the current
checkout and does not run multiple PRs through one worktree.

For each discovered PR, before dispatching its worker:

1. Read and retain `number`, `headRefName`, `headRefOid`, `headRepository.nameWithOwner`,
   `isDraft`, and the reviewer (if any). Re-read the PR immediately before
   isolation; if its head SHA changed, refresh the metadata and use the new tip.
2. Resolve the source push URL from
   `gh repo view <headRepository.nameWithOwner> --json sshUrl --jq .sshUrl`,
   fetch the exact source branch with
   `git fetch --no-tags <source-push-url> <headRefName>`, and create one
   detached worktree at `.worktrees/pr-babysit/<number>-<headRefOid>` from the
   exact `headRefOid`: `git worktree add --detach <path> <headRefOid>`.
   If fetch or worktree creation fails, re-read the PR. If its head or source
   ref changed, refresh metadata and restart isolation; otherwise report that
   PR as blocked and do not dispatch a worker.

3. Verify the worktree is clean and `git rev-parse HEAD` equals `headRefOid`.
   Immediately re-read the PR before dispatching. If it is no longer OPEN,
   remove only this newly-created clean worktree with
   `git worktree remove <path>`, report that PR as terminal/closed, and do not
   dispatch a worker. If it is still OPEN but its head SHA or source
   repository/ref differs, remove the newly-created clean worktree, refresh the
   metadata, and restart isolation. Never delete or reuse an existing path
   unless it is a clean worktree at the same PR head; otherwise report that PR
   as blocked and leave the path intact.

4. Fan out exactly one initial `task` subagent for that PR, passing the absolute
   worktree path, repository, PR number, baseline head SHA, reviewer, source
   repository, source push URL, and source branch.

Each worker must:

- Work only in its assigned worktree and run sections 1–4 for exactly one PR.
  When no reviewer was supplied, skip sections 2–3 and still run the
  current-feedback/CI work and section 4 reporting.
- Re-check that the PR is still OPEN, its source repository/ref is unchanged,
  and its head still has the baseline SHA before editing. If any value changed,
  stop cleanly and report the new state to the parent; do not overwrite newer
  work.
- Never create another babysit worker or another worktree. The worker may
  dispatch at most one `pr-watcher` for its PR when available; that watcher
  cannot fan out or mutate code. The worker owns the feedback loop, validation,
  commits, and push.
- Push commits explicitly to the PR head repository and branch:
  `git push <source-push-url> HEAD:refs/heads/<headRefName>`. Never push a
  detached/temporary branch, use the base repository URL for a fork PR, or
  use an implicit `origin` target.
- After each successful push, set the baseline to the pushed head SHA and
  re-read the source metadata before the next edit; stop only for external
  divergence from that updated baseline.

- Return the final `reviewDecision`, `mergeStateStatus`, CI state, pushed head
  SHA, unresolved findings, and any human blocker. Leave the worktree in place
  when it contains uncommitted changes or a blocker.

Launch all independent workers in one fan-out batch. Keep at most one worker
and one watcher per PR. Wait for every worker result, continue independent PRs
when one blocks, and do not declare batch completion until every PR is
terminal or has a clearly reported human blocker. If a worker fails without a
terminal report, dispatch one corrective worker in the same worktree only
after the original worker has exited; the corrective worker must not fan out or
dispatch a watcher.
After a clean terminal result, run `git worktree remove <path>` for that
command-created worktree. Retain and report any dirty worktree instead of
discarding changes.

## 1. Keep CI green while clearing current PR feedback

CI and review feedback are one loop, not sequential phases. Keep CI green while
you work feedback, and after every push re-check both CI and unresolved review
threads before moving on.
In batch mode, this section is executed independently by each PR worker; the
parent does not share CI state, review threads, or a checkout between workers.


### 1a. CI

- Delegate watching to the **pr-watcher** subagent when available: dispatch it in
  the background with the PR number and the last head SHA you processed, and let
  it report check results, failure log excerpts, and new feedback while you keep
  working. Fall back to the inline `gh` flow below when subagents aren't
  available.
- Keep at most one watcher active for the selected PR and reuse it across the CI and reviewer-feedback phases; do not launch a new watcher for each poll, check, or thread.
- `gh pr checks <n>` — inspect every check.
- Ignore async/UI-only suites that aren't gating and aren't affected by this
  change (e.g. E2E/browser shards on a backend-only PR) **unless one fails** —
  a real failure always matters.
- For any **failed** gating check (tests, lint, format, typecheck, type/dialyzer
  analysis, "enforce no warnings", generated-artifact freshness, migration
  safety, security scan, etc.): open the failing job, reproduce locally, fix at
  the source, re-validate, commit, push, and re-poll.
- Wait for checks with `gh pr checks <n> --watch` when available; otherwise
  poll on an interval using whatever wait mechanism the harness allows (a
  scheduled wake-up, a monitored timer, or `sleep` where permitted). Don't
  busy-spin.
- Resolve conflicts by rebasing the repository's discovered default branch; do
  not assume `main` or `master`.

### 1b. PR feedback

Reviews and inline comments can come from humans or automation. Treat every
review finding by the same standard: verify it against the current code, fix it
when valid, and reply clearly when it is stale, wrong, or needs reviewer input.

1. Pull the current review state and **unresolved** threads:
   ```
   gh pr view <n> --json reviews,reviewDecision
   gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") {
     pullRequest(number:<n>) { reviewThreads(first:100) { nodes {
       id isResolved isOutdated path
       comments(first:5){ nodes{ databaseId author{login} body } pageInfo { hasNextPage endCursor } }
       pageInfo { hasNextPage endCursor } } } } } }'
   ```
   Treat `first:100` and `first:5` as page sizes, not caps: follow each
   `pageInfo.hasNextPage`/`endCursor`; when a page has more results, re-run the
   relevant connection with `after:<endCursor>`, including a separate cursor
   for nested comments on each thread, until exhausted. Inspect each thread's
   latest comment.

2. For each **unresolved** thread and any inline review comment that still
   applies:
   - **Verify the finding against the current code first.** Notes may be stale
     (already fixed in a later commit), outdated, or based on a misread.
   - If **valid**: implement the **minimal** fix, plus a test that would have
     caught it when the change is behavioral. Keep changes tight — no drive-by
     refactors or scope creep.
   - If **stale or wrong**: reply briefly on the thread explaining why (one or
     two concrete sentences).
   - If you **disagree** with a human reviewer: don't silently cave — reply with
     the reasoning and let them call it. Their decision wins once they've
     weighed in.
   - Resolve the thread only when it is genuinely handled: a fix landed, the
     finding is proven stale/wrong, or the reviewer agreed it is a non-issue.
     Leave it open if the ball is in a human reviewer's court.
3. Apply the `user-voice` skill and reply on the thread itself.
4. Reply to review threads through the GitHub API:
   ```
   gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment_db_id>/replies -f body=...
   ```
   Resolve handled threads with `resolveReviewThread(input:{threadId:"<thread_id>"})`
   via the GraphQL API.
5. If you made code changes: run the project's validation gate before pushing.
   Discover the exact command from the repo's agent/context files or scripts
   (e.g. a `precommit`/`check` task, or the formatter + linter + typecheck +
   the specific tests you touched). Never push red. Then commit (conventional
   commit message) and push to the selected PR head. In both modes, use the
   selected PR's explicit source push URL and
   `HEAD:refs/heads/<headRefName>`; never let Git choose an implicit remote.

6. After any push, re-check CI and feedback. Automation may re-review the new
   commit; humans may add follow-up comments. Do not consider this loop cleared
   while gating CI is failing, pending after your push, or newly blocked by a
   review thread.

Guardrails for all PR feedback:

- Never suppress a test, weaken an assertion, or fake a fix to clear a comment.
- Never resolve a thread just to clear the queue — only when it's genuinely
  handled or the reviewer agreed.
- Never relitigate a point you've already conceded. If a reviewer re-raises
  something you've explained, point to the prior reply and leave it to them if
  they still disagree.
- Don't argue in circles. State your case once; if a human reviewer holds, do
  it their way.
- You **cannot** approve on a reviewer's behalf or dismiss their review to
  unblock.
- Only touch what the findings require.

## Consult the oracle

- Before choosing a fix direction that depends on architecture, design intent,
  security posture, ownership, product behavior, or a broad blast radius, consult
  the **oracle** agent. Record the assumption and the oracle's read in your
  private notes; apply the `user-voice` skill to GitHub replies.
- Consult the oracle when a reviewer finding is plausible but conflicts with an
  existing invariant or design tradeoff, when competing fixes both fit the
  evidence, or before saying a finding needs a human architecture, product, or
  design decision.
- Make at most one oracle consultation per head SHA and batch all related current feedback. Consult again only after a relevant commit or requirement changes the evidence.

## 2. Request the reviewer

Once current feedback is cleared and CI is green or still running without known
failures, request the reviewer if one was provided:

```
gh pr edit <n> --add-reviewer <reviewer>
```

Confirm it landed (`gh pr view <n> --json reviewRequests`). Then post a short,
declarative PR comment summarizing: feedback addressed + threads resolved, CI
status, and that `@<reviewer>` is requested. Apply the `user-voice` skill.

## 3. Requested reviewer feedback loop (repeat until reviewer approves)

After the reviewer is requested, keep working their feedback until they **approve**.

1. Poll the review state on an interval — humans aren't instant. Prefer
   dispatching the **pr-watcher** subagent in the background with the PR number
   and a baseline (the review/comment IDs and head SHA you've already
   processed); it reports back only the delta: new reviews, new threads, new
   commits, and CI changes. Where subagents aren't available, wait a few
   minutes between checks using whatever wait mechanism the harness allows (a
   scheduled wake-up, a monitored timer, or `sleep 180` where permitted). Print
   a one-line heartbeat each pass
   (`[babysit] waiting on <reviewer> review — <timestamp>`), and don't spam the API.
   ```
   gh pr view <n> --json reviewDecision,reviews
   gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") {
     pullRequest(number:<n>) { reviewThreads(first:100) { nodes {
       id isResolved isOutdated path
       comments(first:5){ nodes{ databaseId author{login} body } pageInfo { hasNextPage endCursor } }
       pageInfo { hasNextPage endCursor } } } } } }'
   ```
   Treat `first:100` and `first:5` as page sizes, not caps: follow each
   `pageInfo.hasNextPage`/`endCursor`; when a page has more results, re-run the
   relevant connection with `after:<endCursor>`, including a separate cursor
   for nested comments on each thread, until exhausted. Inspect each thread's
   latest comment.

2. Process new or unresolved feedback with the same CI + PR feedback loop and
   guardrails from step 1.
3. After any push, re-clear CI and all current PR feedback before considering
   the requested reviewer loop settled.
4. If the named reviewer **requests changes**, that's a hard gate — keep iterating
   until that same reviewer re-reviews to approval. Require an `APPROVED` review
   from the exact requested reviewer login on the current head; an aggregate
   `reviewDecision` or another reviewer's approval is insufficient. If the
   named reviewer approves, this phase is done.

## 4. Exit condition & report

You are done for a PR when: all current PR feedback is cleared and all gating
CI is green (note any async suites still running). If a reviewer was provided,
they must be requested and must have approved. If no reviewer was provided, the
PR is done after the current-feedback step.

In single-PR mode, report the final `reviewDecision`/`mergeStateStatus` and
state plainly what still blocks merge, if anything. In batch mode, the parent
must emit one result per discovered PR with its final decision, merge state, CI
state, pushed head SHA, unresolved findings, blocker (if any), and worktree
cleanup/retention status. Report the aggregate only after every worker returns.

**You cannot merge or approve on a human's behalf.** Once the reviewer has
approved and everything's green, say it's ready to merge and stop — don't merge it yourself
unless the user asks. Stop and surface to the user if you hit a real blocker (CI
failure you can't fix, a finding that needs a product decision, merge conflicts,
unpushed local commits, or a reviewer ask you can't resolve without a call).
