---
description: Continuously loop, reviewing PRs by an author, optionally scoped to a Linear project — posts casual comments/approval as needed
argument-hint: <github-author> [linear-project] [gh-search-qualifiers...]
---

You are running a **continuous review loop**. You do not stop after one pass.
Exit only when the user interrupts you or the loop reaches the 8-hour inactivity
timeout defined below.

## Arguments

- `$1`: GitHub author handle, required.
- `$2`: Linear project identifier, optional. When it contains `:` or looks like a flag it is a `gh search prs` qualifier instead, so shift it into `$@`, skip the Linear lookup, and review **all** open PRs by `$1` in this repo.
- `$@`: `gh search prs` qualifiers passed through verbatim, for example `draft:false` or `label:bug`. Ignore a bare `PRs`/`prs` token, which is a trigger word the user typed rather than a qualifier.

If `$1` is empty, stop and print the usage:
`/pr-review-loop <github-author> [linear-project] [extra gh qualifiers...]`

## Loop state

Keep `/tmp/pr-review-loop-state.json` so you never re-review unchanged PRs and the loop survives between iterations. Key it by `<owner>/<repo>`, resolved once per run with `gh repo view --json nameWithOwner`, so concurrent loops on different repos don't clobber each other.

```json
{ "<owner>/<repo>": { "<N>": { "head_sha": "<headRefOid>", "reviewed_commits": ["<subject>", ...], "reviewed": true } } }
```

`reviewed_commits` holds the PR-authored commit subjects at the time of the last review, excluding merge and main-sync noise. It is how you tell a real new commit from a rebase. Read only the current repo's sub-object each iteration, update that sub-object after each review, and never drop another repo's entries.

Keep a run-wide idle timer in memory. Start it when the command starts and reset
it only when a candidate PR is newly discovered or a candidate's authored
commit, review, comment, or thread state changes. An unchanged scan, a rebase or
main-sync alone, and this command's own review action do not reset it. When it
reaches 8 hours, print the last iteration status and stop cleanly. The JSON state
remains available so a later run does not re-review unchanged work.
No watcher or wait may run past the idle deadline; schedule a wake-up for the
deadline when it is sooner than the normal polling interval.

## The loop

Run this cycle until the idle timeout. Print
`[pr-review-loop] iteration N — <timestamp>` at the top of each iteration so the
user can see it's alive, work steps 1 through 7, then wait 15 minutes using
whatever wait mechanism the harness allows (a scheduled wake-up, a monitored
timer, or `sleep 900` where permitted).

### 1. Discover PRs

a. When `$2` names a Linear project, use the **linear** MCP tools to fetch open, in-progress issues in it and collect the ticket identifiers the author is actively working on, for example `TICK-42`. If the linear tool is unavailable or fails, fall back to all open PRs by `$1` and infer ticket refs from PR titles and bodies. When `$2` was omitted, skip this step.

b. Find open PRs with `gh search prs` in the current repo, combining `--author "$1" --state open`, any qualifiers from `$@`, and a title/body filter for the step (a) tickets only when a Linear project was given and the lookup succeeded.

c. For each candidate, fetch `gh pr view <N> --json number,title,headRefOid,state,isDraft,headRefName,author,body`. Skip drafts unless the user passed `draft:false`.

### 2. Decide what needs a review

Resolve my handle once per run with `gh api user --jq .login`. The loop reviews _as me_.

**Re-review only on genuinely new commits, never on a rebase or a merge from main.** A head SHA change alone is not new work, since a rebase or a `Merge branch 'main'` rewrites SHAs without adding any of the author's work.

When the **pr-watcher** subagent is available, delegate this check by handing it each candidate PR number plus its `reviewed_commits` baseline, dispatching the batch in parallel, and using its verdict. Otherwise build the list inline:

```bash
gh pr view <N> --json commits --jq '.commits[] | {subject: (.messageHeadline), parents: (.parents|length)}'
```

Drop merge commits (more than one parent) and main-sync subjects such as `Merge branch 'main'`, `Merge remote-tracking`, or `Merge branch 'master'`. The remaining ordered subjects are the PR's `commit_subjects`.

Fetch my reviews with `gh api repos/:owner/:repo/pulls/<N>/reviews`, then decide:

- **My latest review is `APPROVED` and `commit_subjects` is unchanged** → print `PR #N — already approved by me, no new commits, skipping` and post nothing.
- **`commit_subjects` is unchanged** (rebase or main-sync only) → print `PR #N — no new commits since last review (rebase/main-sync ignored), skipping`.
- **New PR, or `commit_subjects` gained entries not in `reviewed_commits`** → review it now. Any prior approval is stale, and only the added commits are in scope for comments.

### 3. Review a PR

```bash
gh pr diff <N>
gh pr view <N> --json files,additions,deletions,commits
```

Review the changes for correctness, regressions, breaking changes, security, and whether tests cover the new or changed behavior. Read the surrounding repo code with `read`/`grep` to ground every claim, never review blind. When available, apply the `implementation-review` skill as the shared review method. This command's new-commit scope, read-only boundary, finding bar, posting policy, and oracle cap override that skill.

#### Change scope

Use the PR description and linked ticket to understand intent and acceptance criteria, not as a strict boundary on which changes may be reviewed. Review every authored change in the current review scope on its merits, including changes that appear outside the ticket's scope. Do not post scope-drift concerns, suggest splitting the PR, or object to an otherwise sound change merely because the ticket did not require it.

A concern is in scope only when the authored changes under review introduce it, make it newly reachable or observable, or materially worsen it. Surrounding unchanged code may establish the trigger and breakage, but it is not independently under review. Do not report pre-existing issues merely discovered while tracing the change, and do not turn adjacent cleanup or refactoring opportunities into suggestions. On repeat passes, "changes under review" means only the commits added since `reviewed_commits`.

Read the complete existing discussion and review history first.

```bash
gh pr view <N> --json comments,reviews
gh api repos/:owner/:repo/pulls/<N>/comments --paginate
```

Build a private ledger of concerns already raised by any reviewer. Match on the underlying trigger and breakage, not exact wording or file location. A concern remains owned by that earlier discussion when its thread is resolved, outdated, minimized, answered, or claims to be fixed, and when later commits move the affected code.

Never post a ledgered concern again. Do not revive it because it still appears present, the earlier fix looks incomplete, or a fresh review independently rediscovers it. Account for its current resolved or unresolved state only in the per-PR console status; never include that state in inline comments, a review body, or a top-level PR comment.

#### Finding bar

Post a finding only when you can state all three of these from code you actually read.

1. `path:line`, the real line in the file, and present in the diff.
2. The trigger, meaning the input, state, or code path that reaches the problem.
3. The breakage, meaning the observable effect on behavior, data, deployment, security, or compatibility.

Missing any one of the three, drop the finding. Do not soften it into a hedge, a caveat, a heads up, or a `worth checking`. Drop nitpicks, style nags, refactor suggestions, and speculation you did not trace in the code. Posting nothing on a sound PR is the expected outcome.

### 4. Consult the oracle for load-bearing decisions

Consult the **oracle** agent before approving or posting a material concern that turns on architecture, design intent, security posture, ownership, invariants, or broad blast radius. Consult it when two readings of the diff both look plausible, when surrounding code suggests an intentional tradeoff you don't understand, or before concluding that a concern needs a human decision.

One consultation per PR per reviewed commit set, batching every related concern. Skip it when repository evidence resolves the concern or nothing meets that bar. Keep the assumption and the oracle's read in your private notes, not in the posted comment.

### 5. Post comments, approval, and replies

Choose exactly one action after reviewing the current commit set:

- `APPROVE`: no new finding clears the bar and no prior material concern remains unresolved.
- `COMMENT`: one or more new findings clear the bar, regardless of prior-concern state.
- `WAIT`: no new finding clears the bar, but a prior material concern remains unresolved.

For `WAIT`, post nothing to GitHub. Report `WAIT` and the prior-concern state in the per-PR console status line, then update loop state normally.

Apply the `user-voice` skill to everything posted as me, including review comments, approval bodies, top-level PR comments, and replies to existing comments or threads. This command grants the posting authority and the skill controls wording only.

Every finding is exactly this, attached to the changed line it belongs to.

```text
<one sentence naming the trigger and the breakage>
<one question the author can answer or push back on>
```

One question per finding, never stacked. Use declarative form for approvals, status updates, and explanatory replies.

**Inline comments:** `gh pr review` can't target individual lines, so use the API. Prefer a single review payload carrying every inline finding.

```bash
gh api repos/:owner/:repo/pulls/<N>/reviews \
  -f event=COMMENT \
  -f body="<only for a concern no changed line fits, usually omit>" \
  -F "comments[][path]=<file>" \
  -F "comments[][line]=<line>" \
  -F "comments[][side]=RIGHT" \
  -F "comments[][body]=<comment>"
```

Use `gh pr view <N> --json files` for valid paths and comment only on lines present in the diff.

**Approval:** for `APPROVE`, approve with no body. Attach no validation, praise, or status commentary.

```bash
gh pr review <N> --approve
```

**Material concerns:** for `COMMENT`, submit a review containing the new line-specific findings. Never use `--request-changes` or a `REQUEST_CHANGES` event. Do not submit an empty `COMMENT` review.

On a repeat pass, comment only on the diff introduced by the new commits, meaning the `commit_subjects` entries that weren't in `reviewed_commits`, not on code the author only rebased.

**Wait:** for `WAIT`, submit no review event, reply, or top-level comment. The single per-PR console status line records that there are no new findings and a prior material concern remains unresolved.

**Console status:** the single per-PR status line may report the overall review state, including counts or a brief status for new findings and previously raised resolved or unresolved concerns. This is private terminal output only; never turn it into drafted or posted PR-comment content.

### 6. Update state

Update the current repo's sub-object in `/tmp/pr-review-loop-state.json` after each PR, preserving other repos' entries. Store the current `headRefOid` as `head_sha` and the filtered `commit_subjects` from step 2 as `reviewed_commits`, so the next iteration can tell a real new commit from a rebase.

### 7. Sleep and repeat

Once every candidate is processed or skipped, print
`[pr-review-loop] iteration N done — reviewed X, skipped Y, sleeping 15m`, wait
15 minutes, and start the next iteration at step 1. When the **pr-watcher**
subagent is available you may dispatch it in the background against the
candidates with their `reviewed_commits` baselines, but do not start the next
iteration until 15 minutes have passed even when it reports relevant activity.
Stop instead when the run-wide idle timer reaches 8 hours.

## Rules

- **MUST** loop continuously until the user interrupts or 8 hours pass without
  relevant activity as defined under Loop state.
- **MUST** apply the `user-voice` skill to everything posted to GitHub, re-running its final check immediately before posting.
- **MUST** drop any finding that cannot name a real line, a trigger, and a breakage. No nitpicks, style nags, `consider X` suggestions, or vague heads ups.
- **MUST** tie every finding to a problem introduced, newly exposed, or worsened by the authored changes in the current review scope.
- **MUST NOT** report a pre-existing issue merely discovered in unchanged code or object to a sound change solely because it exceeds the linked ticket's scope.
- **MUST NOT** post a concern already raised by any reviewer, regardless of thread state, later replies, attempted fixes, code movement, or independently rediscovering it. Track its current state in private console output only.
- **MUST NOT** re-review or re-comment when the PR-authored commit subjects match `reviewed_commits`. A rebase or a merge from main changes SHAs without adding work.
- **MUST NOT** post anything on a PR I already approved until the author pushes new work past that approval. No re-approval, no new comment.
- **MUST NOT** approve a PR with an unresolved material concern. When there are no new findings, choose `WAIT`, post nothing, and record the unresolved state only in the per-PR console status line.
- **MUST** consult the oracle before a load-bearing architecture, design, security, or product judgment that decides an approval, a comment, or a concern requiring human input.
- **MUST NOT** push, merge, close PRs, or request changes. You only comment and approve.
- **MUST NOT** expand scope beyond review. No branch checkouts, no file edits.
- **MUST** keep console output to one status line per iteration plus one line per PR. Never dump diffs or reviews into the terminal.
- If `gh` is not authenticated or the repo has no remote, stop and tell the user.
- If the linear MCP tools are unavailable, fall back to all open PRs by the author and keep looping.
