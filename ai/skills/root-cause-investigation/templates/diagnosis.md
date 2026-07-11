# Diagnosis Template

Start with one outcome:

```text
ROOT CAUSE PROVEN
ROOT CAUSE NOT PROVEN
CANNOT REPRODUCE
```

Then report:

```text
Symptom: <exact expected vs actual behavior>
Reproduction: <command/test/input/environment and result>
First divergence: <path:line or runtime boundary where state/control first becomes wrong>
Mechanism: <specific condition, invariant, ordering, boundary, type, permission, migration, or dependency behavior>
Trigger: <concrete input/state/timing>
Evidence: <observations proving or challenging the mechanism>
Ruled out: <competing causes and discriminating evidence>
Blast radius: <affected callers, data, users, environments, or versions>
Fix direction: <smallest source-level correction, or exact decision required>
Verification: <original repro plus targeted regression coverage>
Missing evidence: <none, or exact information required next>
```

For `ROOT CAUSE NOT PROVEN`, list remaining hypotheses with evidence for and against each. Do not label the best guess as the cause.

For `CANNOT REPRODUCE`, identify the exact environment, data, timing, permissions, configuration, or version difference needed. Do not recommend a speculative code change.
