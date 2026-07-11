# Review Finding Template

Use the caller's format when it is stricter. Otherwise, report each validated finding as:

```text
[<severity>] <short behavioral title>
Location: <path:line>
Requirement: <acceptance criterion, invariant, or intended behavior>
Mechanism: <specific condition/control flow/data flow that fails>
Impact: <observable user, data, security, compatibility, reliability, or maintenance consequence>
Evidence: <code path, runtime value, test, or reproducible state>
Fix: <smallest source-level correction>
Verification: <behavioral test or scenario that fails before and passes after>
```

Severity guidance:

- `critical`: immediate compromise, destructive data loss, or broadly unusable behavior
- `high`: required behavior is wrong or a realistic security/data boundary fails
- `medium`: bounded correctness, reliability, performance, or maintainability failure with a concrete trigger
- `low`: actionable but limited risk; omit when it is merely stylistic

After findings, add:

```text
Three-month risk: <most likely concrete failure mechanism>
Timing: <address now | follow-up>, because <reason>
```

For a clean review:

```text
No validated findings.
Three-month risk: <most likely remaining mechanism or none identified>
Timing: <address now | follow-up | none>, because <reason>
```
