---
description: Babysit a PR — keep CI green, address PR feedback, request a reviewer, then work their feedback until they approve
argument-hint: [pr-number] [reviewer]
---

Babysit a pull request through to ready-to-merge.

Parse `$ARGUMENTS` to decide the PR and reviewer instead of relying on fixed
positions:

- Any token that is only digits, or `#` followed by digits, is the PR number.
- Any non-PR token is the reviewer to request; strip one leading `@` if present.
- If there is no PR number, use the current branch's PR.
- If there is no reviewer, skip the reviewer-request and reviewer-feedback steps
  and say so.
- If there is more than one PR-number token, or more than one reviewer token,
  stop and tell the user the usage:
  `/pr-babysit [pr-number] [reviewer]`.

Resolve PR numbers in the current directory's GitHub repo only. Do not accept a
PR URL or `owner/repo#N` shorthand here; using a bare number avoids ambiguity
with the optional reviewer.

You are driving this autonomously. Do not stop at the first status check —
loop until the exit condition below is met or you hit a genuine blocker that
needs a human.

This command is repo-agnostic: discover the project's owner/repo, default
branch, validation gate, and test commands from the repo itself (git remote,
`gh repo view`, and any agent/context files like `AGENTS.md` / `CLAUDE.md` /
`CONTRIBUTING.md`). Do not assume a language, build tool, or CI layout.

## Voice

Write **everything** you post to GitHub as me — review-thread replies, inline comment replies, top-level PR comments, the reviewer-request summary, request-changes/approval bodies, all of it. All communication, no exceptions. Casually:

- NO emdashes.
- Succinct, direct, and informal, like a teammate's quick note rather than a formal reviewer. One or two sentences beats a paragraph.
- Mostly lowercase, light punctuation, no corporate polish.
- No headers, no bullet scaffolding for short comments, and no "Overall," / "Great work!" / "Nice catch!" / "Thanks for the review!" openers.
- Praise sparingly, only when something is genuinely clever.
- Lead with the point; if something is a real blocker, say so plainly.
- If a comment is feedback for the PR author, phrase it as exactly one sincere question they can answer or push back on. Do not stack multiple questions in one comment; for blockers, ask one direct question that names the concern.
- Skip trivial nits. Only say it if it actually matters.

Examples for replies (don't copy):

- `good catch, that'd leak across orgs, scoped it to org_id now`
- `left this as-is, the retry's already idempotent so a double-send is a no-op. lmk if you'd rather i guard it anyway`
- `done, also added a test for the resolved→reopen path since it was uncovered`
- `fair, pulled the helper out so it's reusable`

## 0. Locate the PR

- Resolve `<owner>/<repo>` from the remote (`gh repo view --json owner,name`)
  before looking up the PR.
- If a PR number was parsed, run
  `gh pr view <n> --json number,title,state,url,reviewDecision,mergeStateStatus,isDraft,headRefName,headRefOid`
  in the current repo. If it does not resolve, stop and say the PR number is not
  in this repo.
- If no PR number was parsed, run
  `gh pr view --json number,title,state,url,reviewDecision,mergeStateStatus,isDraft,headRefName,headRefOid`
  for the current branch. If there is no PR, stop and say so.
- Confirm local `HEAD` matches the pushed branch tip only when the selected PR is
  the current branch's PR (`git rev-parse HEAD` vs `git rev-parse @{u}`). If
  local is ahead, tell the user there are unpushed commits and stop — do not push
  without being asked. If a PR number selected a different branch than the
  current branch, do not make code changes until you have a clean worktree and
  the PR head branch checked out locally; otherwise stop and say which branch is
  needed.

## 1. Keep CI green while clearing current PR feedback

CI and review feedback are one loop, not sequential phases. Keep CI green while
you work feedback, and after every push re-check both CI and unresolved review
threads before moving on.

### 1a. CI

- Delegate watching to the **pr-watcher** subagent when available: dispatch it in
  the background with the PR number and the last head SHA you processed, and let
  it report check results, failure log excerpts, and new feedback while you keep
  working. Fall back to the inline `gh` flow below when subagents aren't
  available.
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
3. **Write replies in my voice** (see Voice above) and reply on the thread
   itself.
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

## Consult the oracle

- Before choosing a fix direction that depends on architecture, design intent,
  security posture, ownership, product behavior, or a broad blast radius, consult
  the **oracle** agent. Record the assumption and the oracle's read in your
  private notes; keep GitHub replies in my voice (see Voice above).
- Consult the oracle when a reviewer finding is plausible but conflicts with an
  existing invariant or design tradeoff, when competing fixes both fit the
  evidence, or before saying a finding needs a human architecture, product, or
  design decision.

## 2. Request the reviewer

Once current feedback is cleared and CI is green or still running without known
failures, request the reviewer if one was provided:

```
gh pr edit <n> --add-reviewer <reviewer>
```

Confirm it landed (`gh pr view <n> --json reviewRequests`). Then post a short PR
comment summarizing: feedback addressed + threads resolved, CI status, and that
`@<reviewer>` is requested. Write it in my voice (see Voice above).

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
       comments(first:5){ nodes{ databaseId author{login} body } } } } } } }'
   ```
2. Process new or unresolved feedback with the same CI + PR feedback loop and
   guardrails from step 1.
3. After any push, re-clear CI and all current PR feedback before considering
   the requested reviewer loop settled.
4. If the reviewer **requests changes**, that's a hard gate — keep iterating until they
   re-review to approval. If they approve, this phase is done.

## 4. Exit condition & report

You are done when: all current PR feedback is cleared and all gating CI is green
(note any async suites still running). If a reviewer was provided, they must be
requested and must have approved. If no reviewer was provided, you are done
after the current-feedback step.
Report the final `reviewDecision`/`mergeStateStatus` and state plainly what still blocks merge, if anything.

**You cannot merge or approve on a human's behalf.** Once the reviewer has
approved and everything's green, say it's ready to merge and stop — don't merge it yourself
unless the user asks. Stop and surface to the user if you hit a real blocker (CI
failure you can't fix, a finding that needs a product decision, merge conflicts,
unpushed local commits, or a reviewer ask you can't resolve without a call).
