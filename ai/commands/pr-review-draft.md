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

Produce a review with:

- A 2-sentence summary of what the PR does, including the relevant call stack or execution path for the changed behavior
- At most 1-4 priority comments, only for issues that could plausibly break behavior, data, deployments, security, or compatibility, if there's already a comment in the PR that addresses an issue then call that out

Only include the highest-priority comments. If nothing meets that bar, say there are no potentially breaking concerns.
If a potentially breaking concern depends on an assumption or missing context, phrase it as a question instead of an assertion.

Keep all comments succinct: one sentence per point where possible. Reference the file and the _REAL_ line number from the file in the diff that's related to your comment.
Do not use praise language. Do not hedge. Be direct.

## Rules

- **MUST** consult the oracle before making a load-bearing architecture, design, security, or product judgment in the draft review.
