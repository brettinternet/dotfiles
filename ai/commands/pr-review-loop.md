---
description: Continuously loop, reviewing PRs by an author that reference a Linear project — posts casual comments/approval as needed
---

You are running a **continuous review loop**. You do not stop after one pass — you loop until the user interrupts you.

## Arguments

- `$1`: GitHub author handle
- `$2`: Linear project identifier
- `$@`: `gh search prs` qualifiers to pass them through verbatim. Ignore a bare `PRs`/`prs` token — that's just a trigger word the user typed, not a qualifier.
<!-- (e.g. `draft:false`, `label:bug`). -->

If `$1` or `$2` is empty, stop immediately and tell the user the usage:
`/pr-review-loop <github-author> <linear-project> [extra gh qualifiers...]`

## Loop state

Persist a state file so you don't re-review unchanged PRs and so the loop survives between iterations:

- `/tmp/pr-review-loop-state.json` — a JSON object keyed by PR number, each entry `{ "head_sha": "...", "reviewed": true }`.

Load it at the start of each iteration. Update it after each review.

## The loop

Run this cycle forever. Between iterations, sleep for **5 minutes** (`bash` with `sleep 300`), then start the next iteration. Print a one-line status line at the top of each iteration like `[pr-review-loop] iteration N — <timestamp>` so the user can see it's alive.

### 1. Discover PRs to review

a. Use the **linear** MCP tools to fetch open, in-progress issues in the `$2` project. The goal is to identify the set of Linear ticket identifiers (e.g. `TICK-42`) that the author is actively working on. If the linear tool isn't available or fails, fall back to **all** open PRs by `$1` in this repo and infer ticket refs from PR titles/bodies.

b. Use `gh search prs` (via `bash`) to find **open** PRs authored by `$1` in the current repo's remote (`gh repo view --json nameWithOwner` to resolve owner/repo). Combine:

- `--author "$1" --state open`
- any user-supplied qualifiers from `$@`
- scope to PRs whose title/body reference a ticket from step (a) when the linear lookup succeeded

c. For each candidate PR, fetch `gh pr view <N> --json number,title,headRefOid,state,isDraft,headRefName,author,body`. Skip drafts unless the user passed `draft:false` (i.e. respect their qualifier choice — by default skip drafts since they're not ready).

### 2. Decide what needs a (re)review

First, resolve **my** handle once per run: `gh api user --jq .login` (this is the reviewer identity — the loop reviews _as me_).

For each candidate PR, check my own latest review and the head SHA:

- **Already approved by me at the current head** → skip entirely, post nothing. Fetch my reviews (`gh api repos/:owner/:repo/pulls/<N>/reviews`); if my most-recent review is `APPROVED` and its `commit_id` is the current `headRefOid`, print `PR #N — already approved by me at <sha>, skipping` and move on. Do not re-approve and do not re-comment.
- **Already reviewed at this exact head SHA** (per the state file) → skip. Print `PR #N — already reviewed at <sha>, skipping`.
- **New PR, or head SHA changed since my last review** → review it now (the author pushed new commits; any prior approval is stale and a fresh pass is warranted).

### 3. Review a PR

For each PR that needs review, fetch the diff and review it as you would a normal PR:

```bash
gh pr diff <N>
gh pr view <N> --json files,additions,deletions,commits
```

Review the actual changes with the lens of: correctness, regressions, breaking changes, security, and whether the tests cover the new/changed behavior. Read the surrounding code in the repo when context is needed — use `read`/`grep` to ground your review, don't review blind.

### 4. Post comments / approval in MY voice

This is critical: **everything you post is written as me, casually.** My tone is:

- _NO_ emdashes.
- Concise and informal. Talk like a teammate leaving a quick PR comment, not a formal reviewer.
- Mostly lowercase most but not all sentences, light on punctuation, no corporate polish.
- No headers, no bullet-point scaffolding for short comments, no "Overall," / "Great work!" / "Nice catch!" openers.
- Praise sparingly and only when something's genuinely clever.
- Lead with the point. If something's a real blocker, say so plainly.
- A trivial nit isn't worth a comment so skip it. Only comment if it actually matters.

_Examples_ of the voice (but don't copy):

- `hmm this N+1s on every row — can we batch the lookup before the loop?`
- `the timeout here swallows the real error, mind re-raising after logging?`
- `lgtm, the migration is reversible too 🙌`
- `think this misses the org_id scoping — devices from other orgs would leak in`

Posting mechanics (`bash` with `gh`):

- **Inline comments on specific lines:** `gh pr review <N> --request --body "<comment>"` won't target lines; for line-specific notes use the GitHub API via `gh api` to post review comments on the diff. Prefer a single review payload with inline comments when there are multiple findings:
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

If you already reviewed this PR before (head SHA changed = new push), post fresh comments only on the **new** diff since the last reviewed commit where possible. If that's hard to determine, just review the full current diff and skip posting findings you've already raised (check the PR's existing comments via `gh pr view <N> --json comments` to avoid duplicates).

### 5. Update state

After processing each PR, write to `/tmp/pr-review-loop-state.json`:

```json
{ "<N>": { "head_sha": "<current headRefOid>", "reviewed": true } }
```

### 6. Sleep and repeat

After every candidate PR in this iteration is processed (or skipped), print a one-line summary: `[pr-review-loop] iteration N done — reviewed X, skipped Y, sleeping 5m`. Then:

```bash
sleep 300
```

Then start the next iteration from step 1.

## Rules

- **MUST** loop continuously. Do not exit after one pass. The only exit is the user interrupting.
- **MUST** write the casual, informal voice described above for everything you post to GitHub. Re-read your draft comments and strip any formality before posting.
- **MUST NOT** post anything on a PR I've **already approved at the current head SHA** — no re-approval, no new comment. Skip it (re-review only once the author pushes new commits past my approval).
- **MUST NOT** post trivial nitpicks, style nags, or "consider X" suggestions that don't matter.
- **MUST NOT** re-review a PR at the same head SHA you've already reviewed — check the state file.
- **MUST NOT** duplicate comments already on the PR — check existing comments first.
- **MUST NOT** approve a PR that has real blockers. Request changes instead.
- **MUST NOT** push, merge, or close PRs. You only comment and approve/request-changes.
- **MUST NOT** expand scope beyond review — don't check out branches or edit files.
- **MUST** keep each iteration's console output short — one status line + per-PR one-liners. Don't dump diffs or reviews into the terminal.
- If `gh` is not authenticated or the repo has no remote, stop and tell the user clearly.
- If the linear MCP tools are unavailable, degrade gracefully to all open PRs by the author (step 1.a fallback) and keep looping.
