---
name: worklease-workflow
description: Coordinate multiple local agents working from the same backlog or work queue with bounded Worklease claims. Use when selecting, claiming, heartbeating, checkpointing, handing off, or releasing shared work.
---

# Worklease Workflow

Use Worklease to prevent cooperating agents on the same host from taking the same work. It coordinates ownership; the backlog provider remains authoritative for workflow state and progress.

## Claim lifecycle

1. Choose one stable resource for the exact unit of work. Every contender must derive the same resource for that unit; use `worklease key` when a provider adapter is available.
2. Inspect current provider state and claims before selection.
3. Acquire before delegation, isolation, or edits. A new attempt gets a new claim; never adopt or clear another active claim.
4. Keep the claim receipt and bearer token private. Heartbeat before half the lease expires and around long work.
5. Recheck ownership, dependencies, and provider state before durable writes.
6. Write and verify a useful provider checkpoint before release. If work is abandoned, let the bounded lease expire.

For work that must own several resources together, use the bundle commands rather than acquiring a partial set one item at a time.

## Guarantees

Worklease is same-host coordination among cooperating callers. `worklease exec` guards a local operation; `worklease replace-file` can additionally enforce an expected file hash. Wrapping a remote provider command does not make that provider mutation fenced or cross-host safe. Use `--coordination-only` when the durable mutation happens outside a guarded local operation and describe the guarantee accurately.

Assignments, statuses, comments, branches, worktrees, and handoff prose are useful visibility but are not claims.

## Fail safely

- Active claim: choose independent ready work or wait.
- Expired claim: acquire a fresh claim and resume from durable provider state.
- Ambiguous acquire/write/release: inspect the exact claim and authoritative provider result before retrying.
- Lost ownership or changed eligibility: stop mutating, preserve safe progress, and hand off clearly.

Expose non-secret diagnostics such as resource, claim ID, owner, revision, and expiry. Never put bearer tokens in logs, checkpoints, comments, or handoffs.
