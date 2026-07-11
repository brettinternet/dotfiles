---
name: implementation-review
description: Review an implementation against its intended behavior for correctness, security, performance, maintainability, tests, and likely future failure modes. Use for branches, PRs, commit ranges, changed files, or completed backlog items; do not use for style-only review or backlog state mutation.
---

# Implementation Review

This skill supplies a reusable review method. It does not grant permission to edit, commit, push, comment on a PR, or mutate backlog/remote state. The invoking command or user request owns scope, fix authority, integration, voice, marker handling, and subagent limits.

## Inputs

Establish these before judging code:

- exact implementation target: diff, branch, PR, commit range, files, or backlog item
- intent sources: user request, acceptance criteria, issue/PR description, and relevant documentation
- explicit non-goals and compatibility constraints
- affected callsites, data flows, tests, interfaces, migrations, and runtime surfaces

If intent cannot be established, report the exact missing source instead of inventing requirements.

## Procedure

1. Read the complete target and enough surrounding code to understand behavior. Do not review a snippet in isolation.
2. Review directly by default. Loading this skill never justifies creating subagents. Obey the caller's existing total budget; when none exists, keep the review in the active agent.
3. Apply every relevant section of [the review rubric](references/rubric.md). Partition any delegated review by independent subsystem or risk-bearing data flow, never by one agent per review dimension.
4. Turn a candidate into a finding only after checking it against current code, intent, callsites, and available runtime/test evidence.
5. For every valid finding, identify the concrete mechanism, affected behavior, location, smallest source-level correction, and behavioral verification that would catch regression.
6. Answer: `If this breaks in 3 months, what is the most likely reason?` Tie the answer to a mechanism and decide whether it must be addressed now or can be followed up.
7. Use [the finding template](templates/finding.md) or the invoking workflow's stricter output format.

## Finding standard

Report only issues that are actionable and plausibly affect required behavior, data, security, compatibility, operations, performance at expected scale, or maintainability through a concrete failure mechanism. Do not report:

- style preferences without behavioral or ownership impact
- speculative concerns contradicted by repository evidence
- findings already fixed in the reviewed state
- pre-existing unrelated problems
- duplicate manifestations of one root issue

When no candidate meets that standard, report a clean review. Do not manufacture findings to fill a quota.

## Fix boundary

If the caller authorizes fixes, return validated findings to that workflow and follow its fix/test/commit rules. Fix at the source rather than suppressing warnings, hiding errors, weakening tests, or introducing a compatibility shim without an explicit requirement.
