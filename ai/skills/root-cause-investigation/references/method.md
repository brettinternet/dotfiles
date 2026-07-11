# Root-Cause Investigation Method

## 1. Establish the failure

1. Restate the exact expected and actual observable behavior.
2. Identify the smallest command, test, input, environment, and state that triggers it.
3. Reproduce the same symptom. Record exact output, stack trace, wrong value, timing, or state transition.
4. If reproduction fails, compare environment, version, data, timing, permissions, and configuration. Do not infer a root cause from a different symptom.

## 2. Mark the causal boundary

Trace backward from the observation through callers and data/control flow. At each boundary compare expected versus actual state:

- external input and validation
- parsing/serialization and type conversion
- business-rule or state-machine decision
- persistence/query/migration behavior
- permissions and ownership scope
- concurrency, ordering, caching, or retry behavior
- dependency or platform response
- final rendering/output

The root-cause candidate is the earliest incorrect transition that is sufficient to produce the later symptom. The line where an exception surfaces is often not that point.

## 3. Maintain competing hypotheses

For each plausible cause, record:

```text
Hypothesis: <specific mechanism>
Predicts: <observable state/output if true>
Evidence for: <observations>
Evidence against: <observations>
Next discriminator: <smallest experiment separating it from alternatives>
```

Drop a hypothesis when its prediction is contradicted. Do not keep several vague variants of the same mechanism.

## 4. Run discriminating experiments

Prefer the smallest experiment that removes the most uncertainty:

- focused failing test or reduced repro
- inspect/log one boundary value without changing behavior
- debugger breakpoint and state inspection
- compare known-good and bad inputs/config/commits
- callsite/reference map
- targeted bisect when the behavior regressed and history is available
- dependency documentation/source check for disputed behavior

Change one causal variable at a time. A workaround that makes the symptom disappear is not proof unless it isolates the mechanism.

Delegate an experiment only when it is independent, materially substantial, and answers a different high-value question. The active investigator owns the hypothesis ledger and synthesis.

## 5. Prove the cause

A root cause is proven only when all are true:

1. A specific condition, invariant, ordering, boundary, type, permission, migration, or dependency behavior is wrong.
2. The mechanism explains every material part of the reported symptom.
3. The triggering input/state is concrete.
4. Evidence distinguishes it from remaining alternatives.
5. Correcting or controlling that mechanism changes the original repro as predicted.

If a proposed cause explains only part of the symptom, continue tracing.

## 6. Decide the outcome

- `PROVEN`: provide mechanism, trigger, evidence, affected path, and the smallest safe fix direction.
- `UNPROVEN`: provide the best-supported hypotheses, evidence for/against, what was ruled out, and the exact next evidence needed.
- `CANNOT REPRODUCE`: provide attempted environment/input/state and the exact missing difference required.

Consult an oracle only after repeated dead ends, equally plausible theories, a disputed load-bearing invariant, or before declaring the investigation human-blocked. Batch all unresolved questions into one consultation and verify its recommendation against evidence.
