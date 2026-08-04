---
name: root-cause-investigation
description: Diagnose a bug, failing test, error, regression, or incorrect runtime behavior by reproducing it and tracing the first causal divergence. Use when the true source is unknown; do not use for speculative cleanup or when a proven fix is already specified.
---

# Root-Cause Investigation

This skill supplies a read-only diagnostic method. It never authorizes edits, commits, pushes, remote updates, issue comments, or delegation; the caller owns those permissions and budgets.

Follow [the investigation method](references/method.md). Maintain one hypothesis ledger and choose experiments by information gain. Stop only with `ROOT CAUSE PROVEN`, `ROOT CAUSE NOT PROVEN` plus exact missing evidence, or `CANNOT REPRODUCE` plus the required environment/input/state. Use [the diagnosis template](templates/diagnosis.md) or the caller's stricter format.

Apply a caller-authorized fix only when the proven source change is small, unambiguous, and contains no material product/architecture choice. Require the original repro and appropriate behavioral regression coverage. Otherwise hand off the diagnosis and fix direction. Never suppress the symptom, weaken a test, catch-and-ignore the error, or add a fallback that preserves the cause.
