---
name: implementation-review
description: Explicit full implementation-review method for correctness, security, performance, maintainability, tests, and likely future failure modes. Use only when a full-review trigger applies to a branch, PR, commit range, changed files, or completed backlog item; do not use for light or style-only review or backlog state mutation.
---

# Implementation Review

This skill supplies a full-review method. It never grants permission to edit, commit, push, post, or mutate backlog/remote state. The caller owns scope, fix authority, integration, voice, markers, and delegation limits.

Use full review for materially complex or multi-subsystem changes; auth/security/privacy, schema/data, concurrency/transaction, public API/compatibility, or meaningful performance risk; or an explicit deep-review request.

Before judging code, establish the exact target, intended behavior, acceptance criteria, non-goals, and compatibility constraints from the request, issue/PR, backlog, and relevant documentation. Report a missing intent source instead of inventing requirements.

## Procedure

1. Read the complete target/diff and enough surrounding code to understand every affected callsite, interface, data flow, migration, test, and runtime surface.
2. Apply the baseline checks and every relevant risk section in [the rubric](references/rubric.md). Correctness is mandatory; do not invent concerns from unrelated sections.
3. Validate each candidate against current code, intent, affected paths, and available test/runtime evidence. Partition allowed delegation by independent subsystem or risk-bearing flow, never by rubric category.
4. Report a finding only when it has a concrete mechanism, trigger, observable impact, location, smallest source-level correction, and behavioral regression check.
5. Answer: `If this breaks in 3 months, what is the most likely reason?` Tie it to a mechanism and decide `address now` or `follow-up`.
6. Use [the finding template](templates/finding.md) or the caller's stricter format.

Report only actionable issues affecting required behavior, data, security, compatibility, operations, expected-scale performance, or maintainability through a concrete failure mechanism. Omit style preferences, unsupported speculation, already-fixed findings, unrelated pre-existing problems, and duplicate symptoms of one cause. A clean review is valid; never fill a quota.

If the caller authorizes fixes, follow its fix/test/commit rules. Fix the source rather than suppressing warnings, hiding errors, weakening tests, or adding an unrequired compatibility shim.
