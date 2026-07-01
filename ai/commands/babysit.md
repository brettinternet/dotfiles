---
description: Babysit the current branch's PR — keep CI green, address PR feedback, request a reviewer, then work their feedback until they approve
---

Babysit the pull request for the current branch through to ready-to-merge.
The reviewer to request is: **$1** (if `$1` is empty, skip the
reviewer-request and reviewer-feedback steps and say so).

You are driving this autonomously. Do not stop at the first status check —
loop until the exit condition below is met or you hit a genuine blocker that
needs a human.

This command is repo-agnostic: discover the project's owner/repo, default
branch, validation gate, and test commands from the repo itself (git remote,
`gh repo view`, and any agent/context files like `AGENTS.md` / `CLAUDE.md` /
`CONTRIBUTING.md`). Do not assume a language, build tool, or CI layout.

## 0. Locate the PR

- `gh pr view --json number,title,state,url,reviewDecision,mergeStateStatus,isDraft`
  for the current branch. If there is no PR, stop and say so.
- Resolve `<owner>/<repo>` from the remote (`gh repo view --json owner,name`)
  for the API calls below.
- Confirm local `HEAD` matches the pushed branch tip
  (`git rev-parse HEAD` vs `git rev-parse @{u}`). If local is ahead, tell the
  user there are unpushed commits and stop — do not push without being asked.

## 1. Keep CI green while clearing current PR feedback

CI and review feedback are one loop, not sequential phases. Keep CI green while
you work feedback, and after every push re-check both CI and unresolved review
threads before moving on.

### 1a. CI

- `gh pr checks <n>` — inspect every check.
- Ignore async/UI-only suites that aren't gating and aren't affected by this
  change (e.g. E2E/browser shards on a backend-only PR) **unless one fails** —
  a real failure always matters.
- For any **failed** gating check (tests, lint, format, typecheck, type/dialyzer
  analysis, "enforce no warnings", generated-artifact freshness, migration
  safety, security scan, etc.): open the failing job, reproduce locally, fix at
  the source, re-validate, commit, push, and re-poll.
- Poll periodically (checks take minutes) until the relevant set is all `pass`.
  Don't busy-spin; sleep between polls.
- Resolve conflicts by rebasing main.

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
       comments(first:5){ nodes{ databaseId author{login} body } } } } } } }'
   ```
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
3. **Write replies in MY voice** — casual, lowercase-leaning, lead with the
   point, no formal scaffolding, no "Thanks for the review!" openers, praise
   only when it's genuinely warranted. Examples of the tone:
   - `good catch, that'd leak across orgs — scoped it to org_id now`
   - `left this as-is, the retry's already idempotent so a double-send is a no-op. lmk if you'd rather i guard it anyway`
   - `done, also added a test for the resolved→reopen path since it was uncovered`
   - `fair, pulled the helper out so it's reusable`
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
   commit message) and push.
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

## 2. Request the reviewer

Once current feedback is cleared and CI is green or still running without known
failures, request the reviewer if `$1` was provided:

```
gh pr edit <n> --add-reviewer $1
```

Confirm it landed (`gh pr view <n> --json reviewRequests`). Then post a short PR
comment summarizing: feedback addressed + threads resolved, CI status, and that
`@$1` is requested. NO emdashes and be succinct.

## 3. Requested reviewer feedback loop (repeat until $1 approves)

After `$1` is requested, keep working their feedback until they **approve**.

1. Poll the review state on an interval — humans aren't instant. Sleep a few
   minutes between checks (`sleep 180`), print a one-line heartbeat each pass
   (`[babysit] waiting on $1 review — <timestamp>`), and don't spam the API.
   ```
   gh pr view <n> --json reviewDecision,reviews
   gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") {
     pullRequest(number:<n>) { reviewThreads(first:100) { nodes {
       id isResolved isOutdated path
       comments(first:5){ nodes{ databaseId author{login} body } } } } } } }'
   ```
2. Process new or unresolved feedback with the same CI + PR feedback loop and
   guardrails from step 1.
3. After any push, re-clear CI and all current PR feedback before considering
   the requested reviewer loop settled.
4. If `$1` **requests changes**, that's a hard gate — keep iterating until they
   re-review to approval. If they approve, this phase is done.

## 4. Exit condition & report

You are done when: all current PR feedback is cleared, all gating CI is green
(note any async suites still running), `$1` is requested, **and `$1` has
approved** (or, if `$1` was empty, through the current-feedback step only).
Report the final `reviewDecision`/`mergeStateStatus` and state plainly what (if
anything) still blocks merge.

**You cannot merge or approve on a human's behalf.** Once `$1` has approved and
everything's green, say it's ready to merge and stop — don't merge it yourself
unless the user asks. Stop and surface to the user if you hit a real blocker (CI
failure you can't fix, a finding that needs a product decision, merge conflicts,
unpushed local commits, or a reviewer ask you can't resolve without a call).
