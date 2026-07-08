---
description: Read-only draft PR review — summary plus at most 4 priority findings, nothing posted to GitHub
argument-hint: <pr-number|url>
---

Switch to plan mode (or otherwise operate strictly read-only). Do not make any changes to code and do not post comments to GitHub.

Review PR $ARGUMENTS using `gh pr view` and `gh pr diff`.
Look up the linked Linear, Jira, or GitHub issue where possible using the branch name or PR comments to get full context.

## Consult the oracle for load-bearing review decisions

Before finalizing a potentially breaking concern that depends on architecture, design intent, security posture, product behavior, ownership, invariants, or broad blast radius, consult the **oracle** agent.

Consult the oracle when competing interpretations of the diff both look plausible, when surrounding code suggests an intentional tradeoff you don't understand, or before calling something human-blocked because the right answer requires an architecture, product, or design decision. Keep the final draft concise and include only the conclusion, not the oracle transcript.

## Output

Produce a review with:

- A 2-sentence summary of what the PR does, including the relevant call stack or execution path for the changed behavior
- At most 1-4 priority comments, only for issues that could plausibly break behavior, data, deployments, security, or compatibility, if there's already a comment in the PR that addresses an issue then call that out

Only include the highest-priority comments. If nothing meets that bar, say there are no potentially breaking concerns.
Reference the file and the _REAL_ line number from the file in the diff that's related to your comment.

## Voice

Write the final draft in my voice:

- Succinct and direct: one sentence per point where possible. No praise language, no hedging, no filler.
- NO emdashes.
- When a concern rests on an assumption or missing context, pose it as an honest question the author can answer, not an assertion.

## Rules

- **MUST** consult the oracle before making a load-bearing architecture, design, security, or product judgment in the draft review.
