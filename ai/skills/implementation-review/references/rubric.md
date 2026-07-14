# Implementation Review Rubric

Use proportional coverage. Correctness is mandatory; apply other sections only when the change can affect them.

## Baseline checks

- Does the implementation satisfy every requirement and acceptance criterion without violating non-goals or compatibility constraints?
- Did the change update every required callsite, generated artifact, configuration, migration, API/UI surface, and behavioral test?
- Is behavior silently gated by a flag, fallback, default, or unreachable path?
- Do boundary, empty, null, malformed, duplicate, partial, error, retry, cleanup, and recovery states preserve invariants?
- Are ordering, ownership, permissions, lifecycle transitions, serialization, migration direction, and version skew correct where relevant?
- Do tests prove observable behavior and failure transitions rather than implementation trivia?

## Security and privacy

Check authentication/authorization at trust boundaries; tenant/org/user isolation and ownership; least privilege and denial when context is absent; secret/sensitive-data exposure in storage, logs, errors, telemetry, caches, or clients; validation of untrusted input/output; and applicable injection, traversal, SSRF, XSS, CSRF, deserialization, process, and path risks.

## Data, concurrency, and reliability

Check transactions, races, reentrancy, idempotency, partial failure, rollback, retries, timeouts, cancellation, backpressure, resource cleanup, cache ownership/invalidation, stale reads, and dependency failure. Verify schema/API compatibility, migrations, generated data, and recovery from interrupted states.

## Performance

Check expected-scale behavior for repeated parsing/work, allocations/copies, blocking, N+1 queries, indexes/query shape, transaction scope, pagination/batching, unbounded loops/retries/queues/recursion/results/payloads/logs/cache keys, frontend render churn, bundle growth, waterfalls, and duplicate requests.

## Maintainability and design

Require fit with canonical ownership boundaries and repository patterns; direct control flow and explicit invariants/types/failures; reuse rather than a second convention or thin wrapper; minimal surface area; tests near the owning behavior; and justification for new optionality, casts, generic machinery, or conditionals. Flag speculative abstraction, drive-by rewrites, stale shims, dead branches, accidental APIs, and complexity moved rather than removed when they create a concrete future failure mechanism.

## Candidate validation

Before reporting, locate the changed/affected line, trace its caller and downstream effect, check intent and conventions, look for an existing guard/test/migration/invariant, identify a plausible triggering state, and state the observable requirement violation. If that chain is incomplete, keep investigating or omit the candidate.

## Three-month risk

Name one most likely concrete mechanism: invariant/ownership drift, unchecked edge state, schema/API/dependency change, ordering/concurrency, permission leakage, data volume, missing behavioral coverage, or unclear source of truth. Address it now when it threatens current acceptance, security, data integrity, compatibility, or expected-scale operation. Follow up only when current behavior is correct, risk is bounded, and the trigger/owner is concrete.
