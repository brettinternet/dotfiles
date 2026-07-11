---
name: root-cause-investigation
description: Diagnose a bug, failing test, error, regression, or incorrect runtime behavior by reproducing it and tracing the first causal divergence. Use when the true source is unknown; do not use for speculative cleanup or when a proven fix is already specified.
---

# Root-Cause Investigation

This skill provides a read-only diagnostic method. It does not authorize code edits, commits, pushes, remote updates, or issue comments. The invoking command or user request decides whether a proven small fix may be applied.

## Investigation contract

- Start from an exact symptom, failing command/test, input, state, or remote report.
- Reproduce before theorizing whenever the environment is available.
- Prefer observed values, control flow, logs, assertions, and commit evidence over plausible stories.
- Find the earliest point where actual state or control flow diverges from correct behavior.
- Explain the complete symptom, not merely one nearby defect.
- Loading this skill never justifies delegation. Obey the caller's total budget; without one, investigate directly.

## Procedure

1. Follow [the investigation method](references/method.md) from reproduction through causal proof.
2. Keep one active hypothesis ledger: evidence for, evidence against, and the next discriminating experiment.
3. Choose experiments by information gain. Do not run several agents or commands that answer the same question.
4. Stop only with one of three evidence-backed outcomes:
   - root cause proven
   - root cause not yet proven, with exact missing evidence
   - cannot reproduce, with exact environment/input/state required
5. Use [the diagnosis template](templates/diagnosis.md) or the caller's stricter output contract.

## Fix boundary

When a caller authorizes fixes, apply one only if the identified source change is small, unambiguous, and has no material product or architecture choice. The fix must make the original repro pass and include behavioral regression coverage where appropriate. Otherwise hand off the proven diagnosis and recommended direction without modifying code.

Never suppress the symptom, weaken a test, catch-and-ignore the error, or add a fallback that leaves the causal mechanism intact.
