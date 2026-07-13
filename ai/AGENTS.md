# User Preferences

## Communication Style

- Be terse and direct. Skip preamble, filler phrases, and trailing summaries.
- Lead with the answer or action, not the reasoning.
- Use plain text over bullet lists when a sentence suffices.

## Development

When implementing something that could be represented as a reusable coding pattern, you MUST tell the user "CODE PATTERN:" and _very_ briefly describe the pattern you're using and whether the pattern matches an existing implementation in the repository. Evaluate if it can share code with the existing pattern and refactor to implement the sharing if possible.

## Tools

- Use `gh` CLI for all GitHub operations. Never construct raw API calls or open browser URLs.
- Use `mise exec <tool> -- <cmd>` when a tool is installed via mise and may not be in PATH.
- Use `chrome-devtools` tool to verify browser changes when working with web UI.
- Prefer fast local CLIs for code navigation: use `rg`/ripgrep for content search, `fd` for file discovery, and `ast-grep` for structural code search/refactors before falling back to fragile regex edits.
- Use `bun` and `bunx` instead of `npm` or `npx`.
- Use `trash` to delete files instead of `rm` so removals are recoverable.
- Use git worktrees when directed to do so and put them within the repository in `.worktrees` if not specified.

## Subagents

If you are running as a subagent (explore, executor, verifier, pr-watcher, oracle), ignore this section entirely and do the task you were given.

- Keep the orchestrating context for decisions, synthesis, and shared-interface coordination; delegate volume work when the agents are available: `explore` (or the built-in Explore) for repo discovery and evidence gathering, `executor` for well-specified implementation, `verifier` for independent acceptance checks, `pr-watcher` for CI/review watching.
- Spec delegated work in one shot: goal, constraints, done-criteria, relevant paths, and the why behind the request — not only the what.
- Start with the cheapest agent that can plausibly succeed; after two failed attempts, escalate one tier or take over — don't retry the same tier a third time. Ad-hoc fan-outs should set a model explicitly rather than inherit the session model.
- Explore findings are inputs, not verified outputs: when a decision hinges on a single scouted fact, re-check it.
- Verify independently: before declaring implementation work complete, run the `verifier` agent with the acceptance criteria and the commits/diff — not your conclusions — and treat any FAIL or UNVERIFIED criterion as open work. Skip it only when an independent review pass is already part of the workflow.
- Consult the `oracle` agent for judgment-dense calls: architecture tradeoffs, competing diagnoses, blockers that may be stale. The weaker the model you are running as, the earlier you should consult it.
- Don't delegate: single-file reads you need immediately, decisions, or anything the user asked you personally to judge.

## Git

- Never run `git push` without explicit instruction.
- Never open PRs without explicit instruction.
- When committing, do not add yourself as a co-author. Omit any `Co-Authored-By` trailer. Make commit messages as concise as possible.
