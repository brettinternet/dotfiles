# Review Finding Template

Use the caller's stricter format when present. Otherwise:

```text
[<severity>] <behavioral title>
Location: <path:line>
Requirement: <criterion or invariant>
Mechanism: <trigger and failing control/data flow>
Impact: <observable consequence>
Evidence: <code path, runtime value, test, or state>
Fix: <smallest source-level correction>
Verification: <behavioral regression scenario>
```

Severity: `critical` for immediate compromise/destructive loss/broad outage; `high` for wrong required behavior or a realistic security/data-boundary failure; `medium` for bounded correctness, reliability, performance, or maintainability failure; `low` only for limited actionable risk, never style.

End with:

```text
Three-month risk: <most likely mechanism or none>
Timing: <address now | follow-up | none>, because <reason>
```

For a clean review, begin `No validated findings.`
