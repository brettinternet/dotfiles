# Diagnosis Template

Start with `ROOT CAUSE PROVEN`, `ROOT CAUSE NOT PROVEN`, or `CANNOT REPRODUCE`, then:

```text
Symptom: <expected vs actual>
Reproduction: <command/input/environment and result>
First divergence: <path:line or runtime boundary>
Mechanism: <specific causal behavior>
Trigger: <input/state/timing>
Evidence: <proof or challenge>
Ruled out: <alternatives and discriminators>
Blast radius: <affected callers/data/users/environments/versions>
Fix direction: <smallest correction or decision>
Verification: <original repro plus regression coverage>
Missing evidence: <none or exact next requirement>
```

For `NOT PROVEN`, list hypotheses with evidence for and against; never label the best guess as cause. For `CANNOT REPRODUCE`, name the missing environment/data/timing/permission/config/version difference and do not recommend speculative code changes.
