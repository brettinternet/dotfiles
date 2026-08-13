---
description: Emit a scannable standup report of your GitHub and backlog activity for a daily or weekly window
argument-hint: [daily|weekly|Nd|YYYY-MM-DD[..YYYY-MM-DD]] [repo:owner/name|org:name]
---

Report what the user did, what is in flight, and what is blocked, for a standup
meeting they are about to speak in. Read-only: never push, comment, review,
merge, or mutate backlog state.

Optimize for glance-ability. The user reads this out loud while scanning it.
Fixed section order, fixed columns, fixed glyphs — the layout must not vary run
to run, so their eyes land in the same place every time.

## Window

Parse `$ARGUMENTS`. Time tokens, first match wins:

- `weekly` / `week` / `7d` — trailing 7 days: today minus 6 at 00:00 → now.
- `daily` / `yesterday` / nothing — previous working day 00:00 → now. On a
  Monday that means Friday 00:00, so the weekend is covered.
- `Nd` — trailing N days.
- `YYYY-MM-DD` — that day, 00:00 → 23:59.
- `YYYY-MM-DD..YYYY-MM-DD` — inclusive range.

Scope tokens are passed through as GitHub qualifiers: `repo:owner/name`,
`org:name`, `user:name`. Without one, the report is org-wide across every repo
the user touched. Reject any other token with the usage line
`/standup [daily|weekly|Nd|YYYY-MM-DD[..YYYY-MM-DD]] [repo:owner/name|org:name]`.

Resolve dates with `date`, not by reasoning about the calendar. GitHub returns
UTC; render every time in the local zone.

## Collect

Resolve the login once: `gh api user --jq .login`. Then make one GraphQL call —
`@me` works in search qualifiers, but `reviews(author:)` needs the literal
login. `$SCOPE` is the scope qualifier or empty. `$FROM`/`$TO` are the window
bounds as `YYYY-MM-DD`. `$SINCE` is the earlier of `$FROM` and 14 days ago, so a
PR that has been sitting in review since last week still shows as in flight.

```sh
gh api graphql \
  -f shipped="is:pr author:@me is:merged merged:$FROM..$TO $SCOPE" \
  -f inflight="is:pr author:@me is:open updated:>=$SINCE sort:updated-desc $SCOPE" \
  -f reviewed="is:pr reviewed-by:@me updated:>=$FROM sort:updated-desc $SCOPE" \
  -f issues="is:issue assignee:@me is:closed closed:$FROM..$TO $SCOPE" \
  -f me="$LOGIN" -f query='
query($shipped: String!, $inflight: String!, $reviewed: String!, $issues: String!, $me: String!) {
  shipped: search(query: $shipped, type: ISSUE, first: 30) {
    nodes { ... on PullRequest { number title url mergedAt additions deletions
      repository { nameWithOwner } } } }
  inflight: search(query: $inflight, type: ISSUE, first: 30) {
    nodes { ... on PullRequest { number title url isDraft reviewDecision updatedAt
      repository { nameWithOwner }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } } } }
  reviewed: search(query: $reviewed, type: ISSUE, first: 30) {
    nodes { ... on PullRequest { number title url state repository { nameWithOwner }
      reviews(author: $me, last: 5) { nodes { state submittedAt } } } } }
  issues: search(query: $issues, type: ISSUE, first: 30) {
    nodes { ... on Issue { number title url closedAt repository { nameWithOwner } } } }
}'
```

Then drop every `reviewed` node with no review `submittedAt` inside the window —
the search qualifier matches PR activity, not review activity, so without this
filter months of stale reviews leak in. Collapse the surviving reviews on a PR
to one verdict, most significant first: `CHANGES_REQUESTED`, `APPROVED`,
`COMMENTED`. Ignore `DISMISSED` and `PENDING`.

If a backlog source resolves in the current directory, add its window activity
via `backlog-source-workflow`, read-only: completed items to Shipped,
in-progress to In flight, blocked items to Blocked. Skip the backlog silently
when no source resolves — do not report its absence.

Use the current session's own state only for the Today section and for blockers
you directly observed. Do not run builds, tests, or broad validation.

## Output

Emit exactly these five sections, in this order, always — an empty one prints
`_none_` in place of its table. No preamble, no legend, no closing summary.

```
# Standup — Tue Aug 12 → Wed Aug 13 (daily)

## Shipped
| Ref | What | Landed |
|---|---|---|
| houston#10081 | ticket due date stored as calendar date | ✅ 11:57 · +491/−34 |

## In flight
| Ref | What | State | Next |
|---|---|---|---|
| cli-agent-orchestrator#572 | Oh My Pi provider | 🔴 changes requested | address feedback |
| houston#10090 | Amp orbs for Houston dev | 👀 awaiting review · CI green | ping reviewer |

## Reviewed
| Ref | What | Verdict |
|---|---|---|
| rover#812 | list supported shells | 💬 commented |

## Blocked
| Ref | Blocker | Needs |
|---|---|---|
| GC-19 | formula run_targets fixture-bound | real-rig decision from Brett |

## Today
- Land houston#10090
- Start GC-19
```

Column and glyph vocabulary is closed. Do not invent new ones.

- `Ref` — repo name without owner, plus `#number`; backlog items use their
  stable ID. Include the owner only when two repos in the report share a name.
- `What` — the subject, ≤ 50 chars: strip the conventional-commit prefix, the
  trailing ticket tag, and any `[patch]`-style marker.
- Glyphs — `✅` merged/done, `👀` awaiting review, `🔵` approved, `🟡` draft,
  `🔴` changes requested or CI failing, `⏳` CI running, `💬` commented,
  `⛔` blocked.
- `State` combines review state and CI: `👀 awaiting review · CI green`. Omit
  the CI half when there are no checks.
- `Next` is ≤ 5 words, imperative.
- `Landed` is local `HH:MM` for a daily window, `Ddd HH:MM` for anything longer.
- Blocked rows come from `CHANGES_REQUESTED`, a failing check rollup, a
  `blocked` label, a blocked backlog item, or a blocker you observed this
  session. A PR already listed in flight may repeat here — the blocker is the
  point.
- `Today` is at most 3 bullets, each grounded in a row above, an unfinished
  backlog item, or in-session state. Write `_nothing queued_` rather than
  inventing plans.

Sort Shipped and Reviewed newest first; sort In flight by most blocking first
(`🔴`, then `👀`, then `🟡`). Cap each table at 8 rows for a daily window and 12
for anything longer, then add one `+N more` row. Never silently truncate.

For a window longer than a day, add a single line directly under the heading
before the first section: `N merged · N open · N reviewed · N closed issues`.
