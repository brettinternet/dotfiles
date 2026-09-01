---
name: thermo-nuclear-code-quality-review
description: Run an explicitly requested, unusually strict maintainability review.
disable-model-invocation: true
---

# Thermo-Nuclear Code Quality Review

Read-only. Preserve behavior and look aggressively for a materially simpler design. Working code is not sufficient when the change leaves a clear structural regression.

## Standard

Seek code judo: better use of the existing architecture that deletes concepts, branches, helpers, modes, conditionals, or layers. Prefer direct boring code over magic, speculative abstraction, thin wrappers, cast-heavy contracts, nullable modes, scattered feature checks, and complexity moved rather than removed.

Challenge:

- state and branch growth that makes valid transitions hard to see
- logic outside the module or boundary that canonically owns it
- duplicate conventions or missed reuse of an existing mechanism
- abstraction that adds indirection without removing concepts
- types, casts, optionality, or fallbacks that obscure invariants
- decomposition that concentrates unrelated responsibilities
- orchestration that serializes independent work or permits partial updates

File size is a signal, not a verdict. Identify the concrete cognitive, ownership, or change cost rather than enforcing a numeric threshold.

## Finding bar

Report only high-confidence structural problems. For each, name the affected code, the concrete maintenance or future-failure mechanism, and the clearest structural correction. Push for the larger simplification when it removes incidental complexity; do not settle for polishing the same design.

Omit naming, formatting, and stylistic preferences. Do not invent findings to fill a quota. A clean result is valid.

## Approval bar

Require no clear structural regression, obvious missed dramatic simplification, unjustified state or branch growth, ownership leak, duplicate convention, magical abstraction, or avoidable coupling introduced by the change.

## Output priority

1. Missed code-judo simplifications
2. Ownership and state-model defects
3. Spaghetti, coupling, and partial-update risks
4. Abstraction, type-boundary, and duplication defects
5. Decomposition and legibility concerns with concrete structural cost

On a repeat review, inspect only the new delta and unresolved prior findings. Return `PASS` when they are resolved and the delta adds no comparable structural regression.
