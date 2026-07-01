---
description: Babysit the current branch's PR — address CodeRabbit feedback until its review is approved, keep CI green, request a reviewer, then work their feedback until they approve
---

Babysit the pull request for the current branch through to ready-to-merge.
The reviewer to request once CodeRabbit approves is: **$1** (if `$1` is empty,
skip the reviewer-request and reviewer-feedback steps and say so).

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

## 1. CodeRabbit feedback loop (repeat until its review phase is complete)

CodeRabbit re-reviews on every push. Your job is to drive its review to
**approved**, not just to answer once.

1. Pull the current review state and **unresolved** threads:
   ```
   gh pr view <n> --json reviews,reviewDecision
   gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") {
     pullRequest(number:<n>) { reviewThreads(first:100) { nodes {
       id isResolved isOutdated path
       comments(first:1){ nodes{ databaseId author{login} body } } } } } } }'
   ```
2. For each **unresolved** CodeRabbit (`coderabbitai`) thread, treat it like a
   real review finding — the same bar as a human reviewer:
   - **Verify the finding against the current code first.** Findings are often
     stale (already fixed in a later commit) or wrong.
   - If **still valid**: implement the **minimal** fix, plus a test that would
     have caught it when the change is behavioral. Keep changes tight — no
     drive-by refactors or scope creep.
   - If **stale or wrong**: skip it, and post a brief reply on the thread
     explaining why (one or two sentences, concrete).
   - Reply to the thread
     (`gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment_db_id>/replies -f body=...`)
     and resolve it
     (`resolveReviewThread(input:{threadId:"<thread_id>"})` via the GraphQL API).
3. If you made code changes: run the project's validation gate before pushing.
   Discover the exact command from the repo's agent/context files or scripts
   (e.g. a `precommit`/`check` task, or the formatter + linter + typecheck +
   the specific tests you touched). Never push red. Then commit (conventional
   commit message) and push.
4. After pushing, **wait for CodeRabbit to re-review** the new commit, then
   loop back to step 1. The phase is complete when the `CodeRabbit` check is
   `pass`/"Review approved" and there are no unresolved CodeRabbit threads.

Guardrails:

- Never suppress a test, weaken an assertion, or fake a fix to clear a comment.
- Never relitigate a point you've already conceded — if CodeRabbit re-raises
  something you've explained, point to the prior reply and resolve.
- Only touch what the findings require.

## 2. Keep CI green

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

## 3. Request the reviewer

Once **CodeRabbit's review is approved** (step 1 complete) — even if some CI is
still running — request the reviewer if `$1` was provided:

```
gh pr edit <n> --add-reviewer $1
```

Confirm it landed (`gh pr view <n> --json reviewRequests`). Then post a short PR
comment summarizing: feedback addressed + threads resolved, CodeRabbit approved,
CI status, and that `@$1` is requested. NO emdashes and be succinct.

## 4. Reviewer feedback loop (repeat until $1 approves)

After `$1` is requested, keep working their feedback until they **approve** —
same rhythm as the CodeRabbit loop, but `$1` is a human, so respond in MY voice.

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
2. For each **unresolved** thread from `$1` (and any inline review comments they
   left), treat it like the real review it is:
   - **Verify against the current code first** — same as CodeRabbit, their note
     might already be handled or rest on a misread.
   - If they're **right**: make the minimal fix (+ a test when it's behavioral),
     run the validation gate, commit, push.
   - If you **disagree**: don't silently cave — reply with the reasoning and
     let them call it. Their decision wins once they've weighed in.
   - Reply on the thread, and resolve it once it's actually addressed (a fix
     landed or they agreed it's a non-issue). Leave it open if the ball is in
     their court.
3. **Write replies in MY voice** — casual, lowercase-leaning, lead with the
   point, no formal scaffolding, no "Thanks for the review!" openers, praise
   only when it's genuinely warranted. Examples of the tone:
   - `good catch, that'd leak across orgs — scoped it to org_id now`
   - `left this as-is, the retry's already idempotent so a double-send is a no-op. lmk if you'd rather i guard it anyway`
   - `done, also added a test for the resolved→reopen path since it was uncovered`
   - `fair, pulled the helper out so it's reusable`
4. After any push, the CodeRabbit loop (step 1) and CI (step 2) apply again —
   re-clear those before considering the reviewer loop settled. Then loop back
   to 4.1.
5. If `$1` **requests changes**, that's a hard gate — keep iterating until they
   re-review to approval. If they approve, this phase is done.

Guardrails:

- Never resolve a reviewer's thread just to clear the queue — only when it's
  genuinely handled or they agreed.
- Don't argue in circles. State your case once; if they hold, do it their way.
- You **cannot** approve on their behalf or dismiss their review to unblock.

## 5. Exit condition & report

You are done when: CodeRabbit approved, all gating CI green (note any async
suites still running), `$1` requested, **and `$1` has approved** (or, if `$1`
was empty, through the request step only). Report the final
`reviewDecision`/`mergeStateStatus` and state plainly what (if anything) still
blocks merge.

**You cannot merge or approve on a human's behalf.** Once `$1` has approved and
everything's green, say it's ready to merge and stop — don't merge it yourself
unless the user asks. Stop and surface to the user if you hit a real blocker (CI
failure you can't fix, a finding that needs a product decision, merge conflicts,
unpushed local commits, or a reviewer ask you can't resolve without a call).
