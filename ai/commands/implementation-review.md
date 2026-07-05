Review my implementation of `$ARGUMENTS` for code quality, security, performance, maintainability, and whether it actually solves the intended work. Commit any fixes.

Treat `$ARGUMENTS` as the exact implementation, branch, PR, commit range, backlog item, or file set to review. Do not review unrelated work except where needed to understand callsites or behavior.

Review process:

1. Establish intent before judging the code:
   - read the relevant backlog item, issue, PR description, commit messages, or nearby documentation
   - identify the expected user-visible behavior and non-goals
   - map the files, callsites, data flows, and tests affected by `$ARGUMENTS`
2. Evaluate correctness first:
   - verify the implementation satisfies every stated requirement
   - check edge cases, error paths, empty states, retries, concurrency, permissions, migrations, and rollback behavior
   - look for partial fixes, stale shims, dead paths, duplicated logic, and behavior hidden behind feature flags or defaults
3. Evaluate security:
   - authentication and authorization boundaries
   - tenant/org/user scoping
   - secret handling and logging
   - injection, traversal, SSRF, XSS, CSRF, deserialization, and unsafe shell/process use where relevant
   - data exposure through errors, telemetry, caching, or client state
4. Evaluate performance:
   - avoidable allocations, copies, repeated work, N+1 queries, unbounded loops, blocking I/O, large payloads, and cache invalidation
   - database indexes, query shapes, pagination, batching, and transaction scope where relevant
   - frontend render churn, bundle growth, waterfalls, and unnecessary client work where relevant
5. Evaluate code quality and maintainability:
   - fit with existing repository patterns
   - clear ownership boundaries and minimal surface area
   - simple names, types, invariants, and failure modes
   - tests that defend behavior instead of implementation trivia
   - no unnecessary abstractions, comments, TODOs, compatibility shims, or drive-by rewrites
6. Evaluate latent failure modes:
   - answer: `If this breaks in 3 months, what’s the most likely reason?`
   - make the answer actionable by tying it to a concrete mechanism: ownership
     drift, unchecked edge case, schema/API change, concurrency, permissions,
     data volume, dependency behavior, missing test coverage, or an unclear
     invariant

Fix policy:

- Fix valid issues at the source, not by suppressing warnings or narrowing tests.
- Keep fixes limited to `$ARGUMENTS` and directly required callsites.
- Add or update targeted tests for behavioral fixes.
- If a finding needs product input, leave the code unchanged for that point and state the exact decision needed.
- If the implementation is already sound, make no code changes.

After review:

- Run the specific tests, linters, typechecks, or manual QA that cover reviewed or fixed behavior.
- Commit any fixes with a concise message.
- Report what was reviewed, what changed, what was verified, the most likely
  3-month breakage reason, and any remaining product decisions or risks.
