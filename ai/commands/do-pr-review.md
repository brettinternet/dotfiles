Switch to plan mode. Do not make any changes to code and do not post comments to GitHub.

Review PR $ARGUMENTS using `gh pr view` and `gh pr diff`.
Look up the linked Linear, Jira, or GitHub issue where possible using the branch name or PR comments to get full context.

Produce a review with:

- A 2-sentence summary of what the PR does, including the relevant call stack or execution path for the changed behavior
- At most 1-2 priority comments, only for issues that could plausibly break behavior, data, deployments, security, or compatibility

Only include the highest-priority comments. If nothing meets that bar, say there are no potentially breaking concerns.
If a potentially breaking concern depends on an assumption or missing context, phrase it as a question instead of an assertion.

Keep all comments succinct: one sentence per point where possible. Reference the file and line number related to your comment.
Do not use praise language. Do not hedge. Be direct.
