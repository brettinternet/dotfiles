---
description: Continuously loop, reviewing PRs by an author, optionally scoped to a Linear project — posts casual comments/approval as needed
argument-hint: <github-author> [linear-project] [gh-search-qualifiers...]
---

You are running a **continuous review loop**. You do not stop after one pass — you loop until the user interrupts you.

## Arguments

- `$1`: GitHub author handle (required)
- `$2`: Linear project identifier (optional). If omitted, or if it's actually a `gh search prs` qualifier (contains `:` or looks like a flag rather than a project identifier), treat it as absent and shift it into `$@` instead — skip the Linear lookup entirely and review **all** open PRs by `$1` in the repo.
- `$@`: `gh search prs` qualifiers passed through verbatim (e.g. `draft:false`, `label:bug`). Ignore a bare `PRs`/`prs` token — that's just a trigger word the user typed, not a qualifier.

If `$1` is empty, stop immediately and tell the user the usage:
`/pr-review-loop <github-author> [linear-project] [extra gh qualifiers...]`

## Loop state

Persist a state file so you don't re-review unchanged PRs and so the loop survives between iterations. Scope it to the current repo so concurrent loops on different repos don't clobber each other:

- `/tmp/pr-review-loop-state.json` — a JSON object keyed by `<owner>/<repo>`, whose value is an object keyed by PR number, each entry `{ "head_sha": "...", "reviewed_commits": ["<subject>", ...], "reviewed": true }`. Resolve `<owner>/<repo>` once per run via `gh repo view --json nameWithOwner`. `reviewed_commits` is the list of PR-authored commit subjects (excluding merge/rebase-from-main noise) at the time of the last review — it's how you tell a real new commit from a rebase.

Load it at the start of each iteration and read only the current repo's sub-object. Update that sub-object after each review; never drop other repos' entries.

## The loop

Run this cycle forever. Between iterations, wait **5 minutes** using whatever wait mechanism the harness allows (a scheduled wake-up, a monitored timer, or `sleep 300` where permitted), then start the next iteration. Print a one-line status line at the top of each iteration like `[pr-review-loop] iteration N — <timestamp>` so the user can see it's alive.

### 1. Discover PRs to review

a. If `$2` (a Linear project) was given, use the **linear** MCP tools to fetch open, in-progress issues in that project. The goal is to identify the set of Linear ticket identifiers (e.g. `TICK-42`) that the author is actively working on. If the linear tool isn't available or fails, fall back to **all** open PRs by `$1` in this repo and infer ticket refs from PR titles/bodies. If `$2` was omitted, skip this step entirely — there's no project scoping, just review all of the author's open PRs.

b. Use `gh search prs` (via `bash`) to find **open** PRs authored by `$1` in the current repo's remote (`gh repo view --json nameWithOwner` to resolve owner/repo). Combine:

- `--author "$1" --state open`
- any user-supplied qualifiers from `$@`
- scope to PRs whose title/body reference a ticket from step (a) only when a Linear project was given and the lookup succeeded

c. For each candidate PR, fetch `gh pr view <N> --json number,title,headRefOid,state,isDraft,headRefName,author,body`. Skip drafts unless the user passed `draft:false` (i.e. respect their qualifier choice — by default skip drafts since they're not ready).

### 2. Decide what needs a (re)review

First, resolve **my** handle once per run: `gh api user --jq .login` (this is the reviewer identity — the loop reviews _as me_).

**Re-review only on genuinely new commits to the PR — never on a rebase or a merge/update from main.** A head SHA change alone is not enough: a rebase onto main or a "Merge branch 'main'" rewrites SHAs without adding any of the author's work, and you MUST NOT re-review or re-comment for that. When the **pr-watcher** subagent is available, delegate this check: hand it each candidate PR number plus its `reviewed_commits` baseline from the state file (dispatch the batch in parallel) and use its verdict — new PR-authored subjects vs "rebase/main-sync only". Otherwise distinguish inline: build the PR's current commit list and reduce it to the author's real work:

```bash
gh pr view <N> --json commits --jq '.commits[] | {subject: (.messageHeadline), parents: (.parents|length)}'
```

Filter that list down to **PR-authored commits**: drop anything that looks like a sync from main — merge commits (more than one parent) and commits whose subject matches `Merge branch 'main'`, `Merge remote-tracking`, `Merge branch 'master'`, or similar. Call the remaining ordered subjects the PR's `commit_subjects`.

For each candidate PR, check my own latest review, then compare `commit_subjects` to the state file's `reviewed_commits`:

- **Already approved by me and no new PR-authored commits since** → skip entirely, post nothing. Fetch my reviews (`gh api repos/:owner/:repo/pulls/<N>/reviews`); if my most-recent review is `APPROVED` and the PR's `commit_subjects` are unchanged vs `reviewed_commits` (SHA may differ from a rebase — that's fine), print `PR #N — already approved by me, no new commits, skipping` and move on. Do not re-approve and do not re-comment.
- **`commit_subjects` unchanged since my last review** (rebase/main-sync only, or nothing new) → skip. Print `PR #N — no new commits since last review (rebase/main-sync ignored), skipping`.
- **New PR, or `commit_subjects` gained one or more entries not in `reviewed_commits`** → review it now. The author pushed real new work; any prior approval is stale and a fresh pass is warranted. Only the added commits are "new" — see step 4 for scoping comments to them.

### 3. Review a PR

For each PR that needs review, fetch the diff and review it as you would a normal PR:

```bash
gh pr diff <N>
gh pr view <N> --json files,additions,deletions,commits
```

Review the actual changes with the lens of: correctness, regressions, breaking changes, security, and whether the tests cover the new/changed behavior. Read the surrounding code in the repo when context is needed — use `read`/`grep` to ground your review, don't review blind.
When available, apply the `implementation-review` skill as the shared review method. This command's new-commit scope, read-only boundary, posting policy, and oracle cap override that skill. Apply the separate `user-voice` skill only when drafting external GitHub communication.

### 4. Consult the oracle for load-bearing review decisions

Before approving, requesting changes, or posting a blocker based on a load-bearing assumption, consult the **oracle** agent when the finding depends on architecture, design intent, security posture, ownership, invariants, or a broad blast radius. Record the assumption and the oracle's read in your private notes; apply the `user-voice` skill to posted GitHub comments.

Consult the oracle when competing interpretations of the diff both look plausible, when surrounding code suggests an intentional tradeoff you don't understand, or before declaring a PR human-blocked because the right fix requires an architecture, product, or design decision.

Make at most one oracle consultation per PR for each reviewed commit set, batching all related load-bearing concerns. Do not consult when repository evidence resolves the concern or no judgment meets that bar.

### 5. Post comments / approval / replies

Load and apply the `user-voice` skill to everything posted as me: review
comments, approval/request-changes bodies, top-level PR comments, and replies to
existing comments or review threads. This command grants the posting authority;
the skill controls wording only. For each new finding directed at the PR author,
ask exactly one sincere question they can answer or push back on. Do not stack
questions; for a blocker, ask one direct question that names the concern. Use
declarative forms for approvals, status updates, and explanatory replies.

Posting mechanics (`bash` with `gh`):

- **Inline comments on specific lines:** `gh pr review` can't target individual lines; use the GitHub API via `gh api` instead. Prefer a single review payload with inline comments when there are multiple findings:
  ```bash
  gh api repos/:owner/:repo/pulls/<N>/reviews \
    -f event=COMMENT \
    -f body="<top-level summary if needed, usually omit>" \
    -F "comments[][path]=<file>" \
    -F "comments[][line]=<line>" \
    -F "comments[][body]=<casual comment>"
  ```
  Use `gh pr view <N> --json files` to get valid paths. Only comment on lines present in the diff.
- **Approval:** if there are no blockers and the change is sound, approve with a short comment:
  ```bash
  gh pr review <N> --approve --body "<short casual approval>"
  ```
  Don't approve if you found real issues — leave them as comments and let the author respond.
- **Changes requested:** only when there's a genuine correctness/security/regression blocker. Use `gh pr review <N> --request-changes --body "<what needs to change, plainly>"`.

If you already reviewed this PR before (new PR-authored commits since = the trigger for this pass), post fresh comments only on the diff introduced by the **new** commits (the entries in `commit_subjects` that weren't in `reviewed_commits`), not on unchanged code the author only rebased. If scoping to just those commits is hard to determine, review the full current diff but skip posting findings you've already raised (check the PR's existing comments via `gh pr view <N> --json comments` to avoid duplicates).

### 6. Update state

After processing each PR, update the current repo's sub-object in `/tmp/pr-review-loop-state.json`, preserving other repos' entries:

```json
{ "<owner>/<repo>": { "<N>": { "head_sha": "<current headRefOid>", "reviewed_commits": ["<subject>", ...], "reviewed": true } } }
```

Store the PR's current `commit_subjects` (the filtered, main-sync-excluded list from step 2) as `reviewed_commits` so the next iteration can tell a real new commit from a rebase.

### 7. Sleep and repeat

After every candidate PR in this iteration is processed (or skipped), print a one-line summary: `[pr-review-loop] iteration N done — reviewed X, skipped Y, sleeping 5m`. Then wait 5 minutes (same wait mechanism as above) and start the next iteration from step 1. When the **pr-watcher** subagent is available, you may instead dispatch it in the background against the candidate PRs with their `reviewed_commits` baselines and start the next iteration when it reports real new work — but never tighter than the 5-minute cadence.

## Rules

- **MUST** loop continuously. Do not exit after one pass. The only exit is the user interrupting.
- **MUST** apply the `user-voice` skill to **everything** posted to GitHub: review comments, approval/request-changes bodies, top-level PR comments, and replies to review threads or existing comments. Re-run its final check immediately before posting.
- **MUST NOT** re-review or re-comment because of a **rebase or a merge/update from main**. A head SHA change with no new PR-authored commit subjects is not new work — skip it. Only genuinely new commits to the PR trigger a fresh pass.
- **MUST NOT** post anything on a PR I've **already approved** when there are no new PR-authored commits since — no re-approval, no new comment. Skip it (re-review only once the author pushes new work past my approval).
- **MUST NOT** post trivial nitpicks, style nags, or "consider X" suggestions that don't matter.
- **MUST NOT** re-review a PR whose PR-authored commit subjects match what you've already reviewed — check the state file.
- **MUST NOT** duplicate comments already on the PR — check existing comments first.
- **MUST NOT** approve a PR that has real blockers. Request changes instead.
- **MUST** consult the oracle before making a load-bearing architecture, design, security, or product judgment that determines approval, request-changes, or a human-required blocker.
- **MUST NOT** push, merge, or close PRs. You only comment and approve/request-changes.
- **MUST NOT** expand scope beyond review — don't check out branches or edit files.
- **MUST** keep each iteration's console output short — one status line + per-PR one-liners. Don't dump diffs or reviews into the terminal.
- If `gh` is not authenticated or the repo has no remote, stop and tell the user clearly.
- If the linear MCP tools are unavailable, degrade gracefully to all open PRs by the author (step 1.a fallback) and keep looping.
