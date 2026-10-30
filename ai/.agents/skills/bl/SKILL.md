---
name: bl
description: Use the bl CLI or MCP for backlog operations in repositories with a backlog.yaml.
---

# bl

Use `backlog-source-workflow` for source selection, dependencies, refinement, and blockers. This skill supplies `bl`-specific mechanics.

- Use the `bl` CLI (or `bl mcp`); never edit item files directly. Follow repository instructions when they name a wrapper such as `task backlog:cli --`.
- Run `bl instructions workflow` once per session before changing items and treat its output as authoritative over [the CLI map](references/cli.md) when they differ.
- Pass `--json` and parse the envelope; check `ok` and the exit code. Never parse human tables.
- `bl` reads and writes the primary checkout's backlog from any linked worktree. Run it from the worktree; do not switch to the primary checkout for task state.
- Read the complete item with `bl show ID --json` before changing it. Pass its `version` to `--if-version` on any write that depends on that read, and reread after every write. Exit 4 means stale: reread and reassess, never blindly retry. Exit 6 `unknown-outcome` may have applied: reread before deciding anything.
- `bl auth login` and `bl trust` need the user; ask instead of running them.

## Claims

With `coordination` in `backlog.yaml`, `bl` owns Worklease claims; never call `worklease` directly for a `bl` item or derive alternate resource keys. A status change is never a claim on its own.

- Select one stable session per loop using the `worklease` skill's session rules, and pass it with `--session` on every claim-affecting call (`next --claim`, `claim`, `heartbeat`, `start`, `set status=`, `done`, `release`). Never switch sessions to get past an uncertain or held claim.
- Select and claim new work with `bl next --claim --start --session S --json`; claim an explicitly assigned item with `bl claim ID --session S`. Plain `bl next` is read-only. On empty results, read `--explain` reasons instead of guessing readiness.
- Heartbeat before half the TTL, including during long work.
- `bl done` writes, then releases. To stop incomplete, persist progress and blockers, then `bl release ID --session S`. Inspect both `transition.status` and `transition.claim` on every status write.
- Under a verified `worklease run` (`WORKLEASE_RUN_ID` set), the supervisor owns the claim: do not claim, heartbeat, or release.

Without coordination, a status is not a claim; do not select an item already in an active status unless it was handed to you.

## Handoffs

A handoff (`bl handoff ID - --session S --json`) records what this session did and where it stopped; it needs a session but no claim. Read prior sessions' handoffs with `bl history ID --json` before resuming an item.

For a linked PR phase, the item is the leading `PREFIX-N` of the PR's head branch, upper-cased (`bl-12-fix-login` is `BL-12`); read the branch from the PR, never the current checkout. Run `bl -C DIR` from a local checkout of the PR's repository, and record one or two lines: what you did and what's next. Pass your harness's session ID (for example `CLAUDE_CODE_SESSION_ID`). Skip silently without a checkout, a session ID, or an item: exit 3 means the branch names no item. Report a failed handoff; never fail the calling pass for one.

## Items

Keep description, acceptance criteria, Definition of Done, plan, notes, and summary distinct. Record each criterion's verification with `bl ac ID check N --evidence TEXT --if-version V`, never as numbered note lines. Preserve checked entries and stable IDs. Use `blocked_by` for required ordering and `parent` only for grouping. Complete an item only when every criterion has evidence and delivery obligations are met; archive only when requested.
