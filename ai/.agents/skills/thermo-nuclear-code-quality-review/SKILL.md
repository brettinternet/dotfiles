---
name: thermo-nuclear-code-quality-review
description: Run an explicitly requested, unusually strict maintainability review.
disable-model-invocation: true
---

# Thermo-Nuclear Code Quality Review

Read-only. Preserve behavior and look aggressively for a materially simpler design.

Seek code judo: better use of existing architecture that deletes concepts, branches, helpers, modes, or layers. Prefer direct boring code over magic, speculative abstraction, thin wrappers, cast-heavy contracts, nullable modes, scattered feature checks, and complexity moved rather than removed.

Review ownership boundaries, state models, coupling, file decomposition, duplicate conventions, and whether related updates can become partially applied. Size alone is evidence, not a verdict; identify the concrete cognitive or change cost.

Report only a few high-confidence structural problems. For each, name the affected code, the concrete maintenance or failure mechanism, and the simplest remedy. Do not report naming or formatting preferences. A clean result is valid.

On a repeat review, inspect only the new delta and unresolved prior findings. Return `PASS` when they are resolved and the delta adds no comparable structural regression.
