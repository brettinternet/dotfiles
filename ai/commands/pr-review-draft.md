---
description: Read-only draft PR review — summary plus at most 4 priority findings, nothing posted to GitHub
argument-hint: <pr-number|url>
---

Switch to plan mode (or otherwise operate strictly read-only). Do not make any changes to code and do not post comments to GitHub.

Review PR $ARGUMENTS using `gh pr view` and `gh pr diff`.
Look up the linked Linear, Jira, or GitHub issue where possible using the branch name or PR comments to get full context.
For light reviews, perform the review directly without loading or applying the `implementation-review` skill. When a full-review trigger applies, load and apply the `implementation-review` skill as the shared full-review method. This command's read-only boundary, priority threshold, output cap, and voice rules override the skill.

## Review mode

Start in **light mode** for a small, tightly scoped, coherent diff. Establish intent and acceptance criteria, inspect the complete diff and directly affected callsites, verify correctness and available targeted tests or other evidence, and report only actionable priority findings. Do not load an exhaustive rubric for lenses the diff cannot affect.

Use **full mode** when the diff is materially large or spans independent subsystems, crosses an authentication, authorization, security, or privacy boundary, changes schema, migrations, or data integrity, changes concurrency or transactions, affects a public API or compatibility surface, carries meaningful performance risk, or includes an explicit deep-review request. Full mode adds every relevant rubric section after the light-mode checks.

Correctness is mandatory in both modes. Light mode may still inspect security, performance, migration, concurrency, or compatibility concerns when the changed behavior directly touches them; proportionality never permits ignoring a relevant risk.

## Consult the oracle for load-bearing review decisions

Before finalizing a potentially breaking concern that depends on architecture, design intent, security posture, product behavior, ownership, invariants, or broad blast radius, consult the **oracle** agent.

Consult the oracle when competing interpretations of the diff both look plausible, when surrounding code suggests an intentional tradeoff you don't understand, or before calling something human-blocked because the right answer requires an architecture, product, or design decision. Keep the final draft concise and include only the conclusion, not the oracle transcript.

Make at most one oracle consultation for the PR and batch all related concerns. Do not invoke it when no concern meets the load-bearing bar above.

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
- If a comment is feedback for the PR author, phrase it as exactly one sincere question they can answer or push back on. Do not stack multiple questions in one comment; for blockers, ask one direct question that names the concern.

## Rules

- **MUST** consult the oracle before making a load-bearing architecture, design, security, or product judgment in the draft review; use at most one consultation and batch all such judgments.
