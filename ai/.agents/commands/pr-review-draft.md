---
description: Draft PR review — read-only unless explicitly told to post comments
argument-hint: <pr-number|url>
---

Draft a review of PR $ARGUMENTS. Switch to plan mode or otherwise operate strictly read-only. Do not change code. Do not post anything to GitHub unless the user explicitly asks to proceed with posting this draft's comments.

## Context

Read the PR with `gh pr view` and `gh pr diff`. Find the linked Linear, Jira, or GitHub issue from the branch name or PR comments and use it for intent and acceptance criteria.

Read the complete existing discussion and review history before drafting anything.

```bash
gh pr view <N> --json comments,reviews
gh api repos/:owner/:repo/pulls/<N>/comments --paginate
```

Drop every concern already raised there, including one the author already addressed.

## Review mode

Start in **light mode** for a small, tightly scoped, coherent diff. Establish intent and acceptance criteria, inspect the complete diff and the directly affected callsites, and verify correctness against targeted tests or other available evidence. Light mode does not load the `implementation-review` skill and does not load a rubric for lenses the diff cannot affect.

Use **full mode** when the diff is materially large or spans independent subsystems, crosses an authentication, authorization, security, or privacy boundary, changes schema, migrations, or data integrity, changes concurrency or transactions, affects a public API or compatibility surface, carries meaningful performance risk, or comes with an explicit deep-review request. Full mode runs the light-mode checks, then loads and applies the `implementation-review` skill for every relevant rubric section. This command's read-only boundary, finding bar, and output cap override that skill.

Correctness is mandatory in both modes. Light mode still inspects security, performance, migration, concurrency, or compatibility when the changed behavior touches them. Proportionality never permits ignoring a relevant risk.

## Finding bar

A finding ships only when you can state all three of these from code you actually read.

1. `path:line`, using the real line number in the file rather than a diff offset.
2. The trigger, meaning the input, state, or code path that reaches the problem.
3. The breakage, meaning the observable effect on behavior, data, deployment, security, or compatibility.

Missing any one of the three, drop the finding. Do not keep it as a hedge, a caveat, a heads up, or a softer question. Drop nitpicks, style preferences, refactor suggestions, speculation you did not trace in the code, and anything outside what the diff can affect.

Keep at most 4 findings, highest priority first. When nothing clears the bar, say there are no potentially breaking concerns and stop.

## Oracle

Consult the **oracle** agent before finalizing a breaking concern that turns on architecture, design intent, security posture, product behavior, ownership, invariants, or broad blast radius. Consult it when two readings of the diff both look plausible, when surrounding code suggests an intentional tradeoff you don't understand, or before saying a concern needs a human decision.

One consultation per PR, batching every related concern. Skip it entirely when no concern meets that bar. Put only the conclusion in the draft, never the transcript.

## Output

Use exactly this shape.

```text
<two sentences on what the PR does, naming the call stack or execution path for the changed behavior>

<path:line>
<one sentence naming the trigger and the breakage>
<one question the author can answer or push back on>
```

One block per finding. One question per finding, never stacked. No praise, no restatement of the author's work, no closing note, and nothing that failed the finding bar.

## Posting when explicitly requested

Only when the user explicitly asks to proceed with posting this draft's comments:

- Attach every finding that maps to a changed line as a file-line comment in a `COMMENT` review. Use the top-level body only for a concern that no changed line fits.
- Approve with no body when there are no material concerns.
- Submit a `COMMENT` review for material concerns. Never submit `REQUEST_CHANGES`.
- Never post a review or approval merely because this command was invoked.

Use the GitHub review API through `gh api`, since `gh pr review` cannot attach comments to individual lines.

## Voice

Apply the `user-voice` skill to the final draft and to any GitHub review explicitly authorized above. It controls wording only and never authorizes posting.

## Rules

- **MUST** stay read-only until the user explicitly authorizes posting.
- **MUST** consult the oracle before a load-bearing architecture, design, security, or product judgment, once per PR with all such judgments batched.
- **MUST** drop any finding that cannot name a real line, a trigger, and a breakage.
- **MUST NOT** include a duplicate concern, a nitpick, a style preference, or a vague suggestion.
