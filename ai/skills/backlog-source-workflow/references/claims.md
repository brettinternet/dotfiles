# Claim Mechanics

Load this reference only before claim acquisition, heartbeat, release, or mutation under a claim.

## Selection and identity

Prefer provider-native fencing, then the repository's fenced `backlog-claim` path, then `local-coordination` through the same helper when actual provider mutations cannot execute inside a fence. The helper stores leases only, never provider workflow state. It uses `BACKLOG_CLAIM_HOME` or `$XDG_STATE_HOME/backlog-work-claims` (`~/.local/state` by default) and combines a per-resource OS lock with SQLite compare-and-set state.

Derive canonical resources with:

```text
backlog-claim key --provider <kind> --source <canonical-locator> --item <stable-id>
```

Before deriving a key for a local source, resolve it against the intended repository context and confirm that `git rev-parse --show-toplevel` identifies that repository. Never resolve a relative source against an incidental agent shell directory. On `canonical-control-root-unavailable`, report `pwd`, the resolved source, Git toplevel/common-dir, and `BACKLOG_CONTROL_ROOT` before retrying.

Loose Markdown yields a fenced source resource; Backlog.md and GitHub yield fenced item resources. Linear and unfenced providers yield coordination-only item resources. Use `key --coordination-only` when a normally fenced provider must use an unfenced first-party mutation path.

For Backlog.md in a Git repository, derive the source locator and run all `backlog` reads and writes from the repository's canonical primary/control checkout, even when the pass was invoked from another worktree. The helper defaults to the primary checkout containing the shared Git directory; `BACKLOG_CONTROL_ROOT` may name another registered checkout when the Backlog.md UI also uses it. Map a worktree-local source by repository-relative path; never let the implementation worktree's copy become provider state. If the control checkout, mapping, or safe provider working directory is missing or ambiguous, do not acquire/start work through a fallback checkout; return `WAIT` or the relevant capability diagnostic.

Generate unique claim, session, worker-attempt, and operation IDs. Acquire with current provider eligibility/version. Coordination-only acquisition must include `--coordination-only`, and its receipt must say `local-coordination`. Resolve ambiguous acquisition by exact claim ID; never start or transfer work while ownership is uncertain.

## Lease lifecycle

`acquire` defaults to 900 seconds and rejects TTLs above 3600 seconds. Retain token/revision receipts. Retrying the same claim ID is idempotent; every new ownership epoch uses a fresh ID/token and later revision. Even the same agent/session cannot adopt or renew another unexpired epoch.

Heartbeat before half the lease elapses and around long work. Heartbeat and release require the exact claim ID/token/revision. Release only after a durable checkpoint and with a non-blank reason. A coherent handoff checkpoints and releases; abandoned work is reclaimed only after expiry with a fresh claim. Never steal or clear an active claim.

## Writes

An item `WorkClaim` owns the whole pass and retains the existing one-pass lease lifecycle. A separate short same-host provider/repository mutation transaction lock serializes only shared Backlog.md provider writes, any corresponding provider-state commit, and Git integration in the canonical checkout. `backlog-claim exec` acquires it for Backlog.md mutations; use `backlog-claim control-exec` with the current item claim for one guarded `git` checkpoint or integration command. Refresh provider/Git state inside it, perform the minimal mutation/integration, and release it immediately. Never hold it during implementation, tests, or review, and never use it as item ownership. Unresolved contention or unsafe shared state returns `WAIT`. It does not fence provider writes from another host.

Under a fenced helper claim:

- run exactly one supported `backlog` or `gh` mutation through `backlog-claim exec`; the helper holds/renews the fence and advances the claim revision. Backlog.md commands use the canonical control checkout as their validated provider working directory
- write loose Markdown only with `backlog-claim replace-file`, current claim credentials, a fresh operation ID, and the expected source SHA-256

Never pass coordination-only mutations through `exec`/`replace-file`; both must reject that guarantee. Reuse an operation ID only to recover the same request's lost response. Changed inputs are a conflict.

Under `local-coordination`, heartbeat and validate the exact lease plus provider eligibility/version immediately before each direct first-party mutation, then reread both immediately afterward. Stop on lease loss, assignee conflict, provider change, failure, or ambiguity. The lease does not prevent the provider mutation, so always report `LOCAL COORDINATION (UNFENCED)` and never imply provider-side/cross-host fencing.

Assignments, labels, comments, statuses, branches, worktrees, handoffs, and ordinary lock files are visibility only. Backlog.md may project the active agent as assignee through its selected write path. Linear may assign an unassigned item to the authenticated user after acquisition; preserve a different assignee. Assignment never controls eligibility.
