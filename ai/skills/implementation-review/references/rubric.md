# Implementation Review Rubric

Apply only sections relevant to the target, but never skip correctness.

## Intent and coverage

- Does the implementation satisfy every explicit requirement and acceptance criterion?
- Are all required callsites, generated artifacts, configuration, migrations, API/UI surfaces, and tests updated?
- Is any behavior silently gated by a flag, default, fallback, or unreachable path?
- Were obsolete paths removed without leaving aliases, stale shims, dead branches, or duplicate implementations?

## Correctness

- Boundary and edge values; empty, null, missing, duplicate, malformed, and partial states
- Error propagation, cleanup, rollback, retries, idempotency, and recovery
- Ordering, races, concurrency, reentrancy, transactions, and partial failure
- Permissions, tenant/org/user scoping, state transitions, lifecycle ownership, and invariants
- Schema/API compatibility, migration direction, generated data, serialization, and version skew
- Tests that defend observable behavior, failure modes, and transitions rather than implementation trivia

## Security and privacy

- Authentication and authorization at every trust boundary
- Tenant/org/user isolation and object ownership
- Secret, token, credential, and sensitive-data handling in storage, logs, errors, telemetry, caches, and client state
- Injection, traversal, SSRF, XSS, CSRF, unsafe deserialization, shell/process execution, and path handling where relevant
- Validation at external boundaries and safe handling of untrusted input/output
- Least privilege and denial behavior when context or permission is absent

## Performance and reliability

- Avoidable allocations, copies, repeated parsing, repeated work, and synchronous blocking
- N+1 queries, missing indexes, poor query shapes, transaction scope, pagination, batching, and unbounded result sets
- Unbounded loops, retries, queues, recursion, memory growth, payloads, logs, or cache keys
- Cache correctness, invalidation, stampedes, stale reads, and ownership
- Frontend render churn, bundle growth, client waterfalls, duplicate requests, and unnecessary client computation
- Timeouts, backpressure, cancellation, resource cleanup, and dependency failure behavior

## Maintainability and design

- Fit with canonical repository patterns and ownership boundaries
- Minimal surface area, direct control flow, clear invariants, names, types, and failure modes
- Shared logic reused instead of a second convention or thin pass-through abstraction
- No speculative abstraction, drive-by rewrite, redundant comment, TODO, deprecated path, or accidental public API
- Tests located with the owning behavior and resilient to internal refactoring
- New optionality, casts, generic mechanisms, or conditionals justified by actual domain variation

## Latent failure

Answer the three-month question with one concrete mechanism, such as:

- ownership or invariant drift
- unchecked edge state
- schema/API/dependency change
- concurrency or ordering
- permission/scope leakage
- data volume or cardinality
- missing behavioral coverage
- unclear source of truth

Address it now when it can violate current acceptance, security, data integrity, compatibility, or expected-scale operation. Leave it as a follow-up only when current behavior is correct, the risk is bounded, and the follow-up has a concrete trigger or owner.

## Candidate validation

Before reporting a finding:

1. Locate the exact changed or directly affected line.
2. Trace the behavior through its caller and downstream effect.
3. Check intent and repository conventions.
4. Look for an existing guard, invariant, test, migration, or ownership rule that resolves the concern.
5. Determine a plausible input/state that triggers the failure.
6. State what observable result differs from the requirement.

If any required link in that chain is missing, keep investigating or omit the finding.
