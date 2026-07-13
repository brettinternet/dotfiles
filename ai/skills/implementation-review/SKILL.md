---
name: implementation-review
description: Explicit full implementation-review method for correctness, security, performance, maintainability, tests, and likely future failure modes. Use only when a full-review trigger applies to a branch, PR, commit range, changed files, or completed backlog item; do not use for light or style-only review or backlog state mutation.
---

# Implementation Review

This skill supplies a reusable full-review method. It does not grant permission to edit, commit, push, comment on a PR, or mutate backlog/remote state. The invoking command or user request owns scope, fix authority, integration, voice, marker handling, and subagent limits.

## Inputs

Establish these before judging code:

- exact implementation target: diff, branch, PR, commit range, files, or backlog item
- intent sources: user request, acceptance criteria, issue/PR description, and relevant documentation
- explicit non-goals and compatibility constraints
- affected callsites, data flows, tests, interfaces, migrations, and runtime surfaces

If intent cannot be established, report the exact missing source instead of inventing requirements.

## Review mode

This skill is the full-review method. Load and apply it only after the invoking workflow selects full mode because at least one full-review trigger applies:

- a materially large or complex diff or independent subsystems
- an authentication, authorization, security, or privacy boundary
- schema, migration, or data-integrity changes
- concurrency or transaction behavior
- a public API or compatibility surface
- meaningful performance risk
- an explicit deep-review request

Full mode begins with the baseline intent, acceptance, correctness, and targeted-evidence checks, then applies every relevant section of [the review rubric](references/rubric.md), without inventing irrelevant concerns.

Correctness is mandatory. The full-review triggers select the depth of the review rather than permitting a relevant risk to be ignored.

## Procedure

1. Establish the exact target, intent, acceptance criteria, non-goals, and compatibility constraints before judging the code.
2. Select full mode from the change surface and the triggers above. The invoking command may require stricter scope or output, but loading this skill never grants permission to edit, commit, push, comment on a PR, or mutate backlog or remote state.
3. Read the complete target and enough surrounding code to understand behavior. Inspect the complete diff and directly affected callsites, and map independent subsystems and risk-bearing data flows.
4. Verify intent, acceptance, correctness, and available targeted tests or runtime evidence, checking relevant edge states, errors, and ownership boundaries. Then apply every relevant section of [the review rubric](references/rubric.md), without inventing irrelevant concerns. Partition any delegated review by independent subsystem or risk-bearing data flow, never by one agent per review dimension.
5. Turn a candidate into a finding only after checking it against current code, intent, callsites, and available runtime/test evidence.
6. For every valid finding, identify the concrete mechanism, affected behavior, location, smallest source-level correction, and behavioral verification that would catch regression.
7. Answer: `If this breaks in 3 months, what is the most likely reason?` Tie the answer to a mechanism and decide whether it must be addressed now or can be followed up.
8. Use [the finding template](templates/finding.md) or the invoking workflow's stricter output format.

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
