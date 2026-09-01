---
description: Find a bug's root cause and apply a small unambiguous fix
argument-hint: <symptom|failing-test|error|repro-steps|remote-ref> [suspected-area]
---

Diagnose the exact symptom in `$ARGUMENTS`.

Reproduce the reported behavior before theorizing. Record expected versus actual behavior and the smallest triggering command, input, environment, and state. If it does not reproduce, identify the missing difference instead of guessing.

Trace backward through callers and data or control flow to the first incorrect transition. Distinguish the cause from where the symptom appears. When several explanations still fit, choose the smallest experiment that separates them and discard contradicted hypotheses.

Call the root cause proven only when one specific mechanism explains the material symptom, has a concrete trigger, and changing or controlling that mechanism changes the original reproduction as predicted.

Apply a fix only when the source change is small, unambiguous, and requires no product or architecture decision. Fix the cause rather than suppressing the symptom. Rerun the original reproduction and add regression coverage when it protects observable behavior.

Do not mutate a remote issue supplied as context. Do not commit, push, or open a PR unless explicitly requested.

Report the mechanism and evidence, the fix and verification when applied, or the exact evidence still needed.
