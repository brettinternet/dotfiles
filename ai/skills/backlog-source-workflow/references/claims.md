# Claim Mechanics

Load this reference only before claim acquisition, heartbeat, release, or mutation under a claim.

## Selection and identity

Prefer provider-native fencing, then the repository's fenced `backlog-claim` path, then `local-coordination` through the same helper when actual provider mutations cannot execute inside a fence. The helper stores leases only, never provider workflow state. It uses `BACKLOG_CLAIM_HOME` or `$XDG_STATE_HOME/backlog-work-claims` (`~/.local/state` by default) and combines a per-resource OS lock with SQLite compare-and-set state.

Derive canonical resources with:

```text
backlog-claim key --provider <kind> --source <canonical-locator> --item <stable-id>
```

Loose Markdown yields a fenced source resource; Backlog.md and GitHub yield fenced item resources. Linear and unfenced providers yield coordination-only item resources. Use `key --coordination-only` when a normally fenced provider must use an unfenced first-party mutation path.

Generate unique claim, session, worker-attempt, and operation IDs. Acquire with current provider eligibility/version. Coordination-only acquisition must include `--coordination-only`, and its receipt must say `local-coordination`. Resolve ambiguous acquisition by exact claim ID; never start or transfer work while ownership is uncertain.

## Lease lifecycle

`acquire` defaults to 900 seconds and rejects TTLs above 3600 seconds. Retain token/revision receipts. Retrying the same claim ID is idempotent; every new ownership epoch uses a fresh ID/token and later revision. Even the same agent/session cannot adopt or renew another unexpired epoch.

Heartbeat before half the lease elapses and around long work. Heartbeat and release require the exact claim ID/token/revision. Release only after a durable checkpoint and with a non-blank reason. A coherent handoff checkpoints and releases; abandoned work is reclaimed only after expiry with a fresh claim. Never steal or clear an active claim.

## Writes

Under a fenced helper claim:

- run exactly one supported `backlog` or `gh` mutation through `backlog-claim exec`; the helper holds/renews the fence and advances the claim revision
- write loose Markdown only with `backlog-claim replace-file`, current claim credentials, a fresh operation ID, and the expected source SHA-256

Never pass coordination-only mutations through `exec`/`replace-file`; both must reject that guarantee. Reuse an operation ID only to recover the same request's lost response. Changed inputs are a conflict.

Under `local-coordination`, heartbeat and validate the exact lease plus provider eligibility/version immediately before each direct first-party mutation, then reread both immediately afterward. Stop on lease loss, assignee conflict, provider change, failure, or ambiguity. The lease does not prevent the provider mutation, so always report `LOCAL COORDINATION (UNFENCED)` and never imply provider-side/cross-host fencing.

Assignments, labels, comments, statuses, branches, worktrees, handoffs, and ordinary lock files are visibility only. Backlog.md may project the active agent as assignee through its selected write path. Linear may assign an unassigned item to the authenticated user after acquisition; preserve a different assignee. Assignment never controls eligibility.
