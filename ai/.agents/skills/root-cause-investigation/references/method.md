# Root-Cause Investigation Method

## 1. Establish the failure

Record exact expected versus actual behavior and the smallest triggering command/test, input, environment, and state. Reproduce the same symptom before theorizing. If it does not reproduce, compare versions, data, timing, permissions, configuration, and environment; never infer a cause from a different symptom.

## 2. Find the first divergence

Trace backward from the observation through callers and data/control flow. At each relevant boundary compare expected and actual state: external input/validation, parsing/types, business rules/state transitions, persistence/migrations, permissions/ownership, concurrency/order/cache/retry, dependencies/platform, and final output. The root candidate is the earliest wrong transition sufficient to produce the symptom, not necessarily where the error surfaces.

## 3. Maintain competing hypotheses

For each distinct plausible mechanism record:

```text
Hypothesis: <mechanism>
Predicts: <observable result if true>
For: <evidence>
Against: <evidence>
Next discriminator: <smallest separating experiment>
```

Drop contradicted hypotheses; do not keep vague variants of one story.

## 4. Run discriminating experiments

Choose the smallest experiment with highest information gain: reduced repro/focused test, one boundary value, debugger state, known-good/bad input/config/commit, callsite map, targeted bisect, or primary dependency docs/source. Change one causal variable at a time. A workaround is proof only when it isolates the mechanism. Delegate only independent, substantial experiments answering different high-value questions; the active investigator owns the ledger and synthesis.

## 5. Prove the cause

Require all five:

1. one specific wrong condition, invariant, ordering, boundary, type, permission, migration, or dependency behavior
2. a mechanism explaining every material symptom
3. a concrete triggering input/state
4. evidence distinguishing remaining alternatives
5. correction/control of that mechanism changes the original repro as predicted

Otherwise continue or report unproven.

## 6. Conclude

- `PROVEN`: mechanism, trigger, evidence, affected path, and smallest safe fix direction
- `UNPROVEN`: hypotheses with evidence for/against, ruled-out causes, and exact next evidence
- `CANNOT REPRODUCE`: attempted state and exact missing difference

Consult one batched oracle only after repeated dead ends, equally plausible theories, a disputed load-bearing invariant, or before declaring human-blocked. Verify its advice against observed evidence.
