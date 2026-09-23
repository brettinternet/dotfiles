# User Preferences

## Communication Style

- Be succinct and direct. Lead with the answer or action; skip preamble, filler phrases, and trailing summaries.
- Prefer a short example, diff, or table over abstract description.
- Use plain text over bullet lists when a sentence suffices.

## Development

Prefer the simplest design that satisfies the requirement. Do not add abstractions, indirection, configuration, or extensibility that no current requirement exercises. A diff notably larger than the task implies needs justification or shrinking.

When the same approach fails the same way twice, change approach or surface the blocker; don't retry variations.

When making technical decisions, do not give much weight to development time cost. Instead, prefer quality, simplicity, robustness, scalability, and long term-maintainability.

Before introducing a new pattern, search for an existing implementation and reuse or extend it. Announce "CODE PATTERN:" with a very brief description only when introducing a genuinely new reusable pattern or consolidating a duplicate.

## Tools

- Use `gh` for all GitHub operations, including `gh api`/`gh api graphql` when no subcommand covers it; never curl the API or open browser URLs.
- Use `mise exec <tool> -- <cmd>` when a tool is installed via mise and may not be in PATH.
- Verify web UI changes in an actual browser using the agent's available browser tooling.
- Prefer fast local CLIs for code navigation: use `rg`/ripgrep for content search, `fd` for file discovery, and `ast-grep` for structural code search/refactors before falling back to fragile regex edits.
- Use `bun` and `bunx` instead of `npm` or `npx`.
- When fixtures or documentation contain destructive command text, use `edit` or `write`; never embed that text in a Bash heredoc or inline interpreter command. Run validation separately so safety guards do not mistake fixture data for an executable command.
- NEVER use `rm`; use `trash` to delete files so removals are recoverable.
- Never carry generic shell variables such as `$dir`, `$path`, `$target`, or `$tmp` across interactive commands. Keep them local to one shell function or one command invocation and use a purpose-specific name.
- Never execute or suggest `trash`, `rm`, or destructive `find` commands with variable-derived targets unless cleanup occurs in the same shell function, the variable is local, the resolved target is beneath the canonical OS temporary directory with an expected prefix, and an ownership marker is present. Otherwise leave the path in place and report it. Never use `$HOME` as a destructive target.

## Subagents

If you are running as a subagent of any kind, ignore this section entirely and do the task you were given.

- Work directly by default. Delegate only when a child materially improves at least one of: independent evidence, context isolation, specialist capability, parallel latency, or isolated execution. Task size alone is not a reason to delegate.
- Keep the orchestrating context for decisions, synthesis, and shared-interface coordination. Use `explore` (or the built-in Explore in Claude Code) for substantial read-heavy discovery, `executor` for bounded implementation with settled requirements, `verifier` for independent acceptance checks, and `pr-watcher` for CI/review watching.
- Delegate externally directed wording to `writer` whenever the `user-voice` or `draft-in-editor` skill applies. Give it the facts and constraints, then use its returned wording without rewriting it in the caller.
- Spec delegated work in one shot: goal, constraints, done-criteria, relevant paths, and the why behind the request — not only the what.
- Start with the cheapest agent and lowest effort that can plausibly succeed; reserve strong high-effort agents for consequential uncertainty or risk. After two failed attempts, escalate one tier or take over — don't retry the same tier a third time. Ad-hoc fan-outs (built-in general-purpose or Explore agents) must set a model explicitly rather than inherit the session model.
- Use one explorer by default. Fan out only across distinct evidence seams that can finish without each other's intermediate state; do not duplicate scouts for confidence.
- Explore findings are inputs, not verified outputs: when a decision hinges on a single scouted fact, re-check it.
- For substantial changes, choose either `reviewer` for defect discovery or `verifier` for criteria-based executable checks, and name the specific risk or criteria it should concentrate on. Use both only when the change is materially risky and they cover different failure classes. Skip both for small changes directly exercised by focused checks.
- Use `oracle` only for consequential architecture tradeoffs, competing diagnoses after evidence gathering, suspected decision drift, or a blocker that may be stale. Do not use it as routine confirmation.
- Use `thermo-nuclear-code-quality-review` only for an explicitly requested maintainability audit.
- Don't delegate: single-file reads you need immediately, simple searches or commands, tightly coupled sequential work, decisions, or anything the user asked you personally to judge.

## Human-required blockers

- Exhaust repository evidence and available tools, and complete everything not blocked, before escalating. When only a person can supply a consequential decision, credential or permission, external action, private input, or environment state, actively prompt the user in the current session with the available question or user-input tool; do not merely announce the blocker and end.
- Make the request actionable: name the exact input or action, what it blocks, evidence and attempts, the recommended response, and only materially different alternatives. Batch related questions.
- Stay in the workflow and resume after the answer. End blocked only when user interaction is unavailable or noninteractive, the user cannot or declines to unblock it, or the required external state remains unavailable. For provider-backed work, checkpoint the request and objective unblock condition before ending.

## Git

- Never run `git push` without explicit instruction.
- Never open PRs without explicit instruction.
- A user-invoked command whose documented flow pushes or opens a PR counts as explicit instruction, scoped to that command's own branch.
- When committing, do not add yourself as a co-author. Omit any `Co-Authored-By` trailer. Make commit messages as concise as possible.
- Default every agent-created worktree to `<repo>/.worktrees/<name>`. Use another location only when the user or repository configuration explicitly specifies it.
- When you control worktree creation, use `mise exec worktrunk -- wt switch --create <branch> --base <base> --no-cd --format=json` instead of `git worktree` or harness-native isolation. Work from the returned path; repository `.config/wt.toml` hooks prepare it, and the personal post-start hook opens a Herdr workspace when running inside Herdr. Review and approve project hooks before unattended creation; do not bypass required setup merely for convenience.
- Harness-native isolation remains acceptable when the harness requires it or Worktrunk cannot support the task. Treat it as a fallback: record the created path and branch, and explicitly run any required repository setup and teardown that Worktrunk hooks would otherwise provide.
- Destructive Git cleanup is pre-authorized only for a verified non-primary session-owned worktree. Agents may discard its changes, remove it even when dirty or unmerged, and delete or move its associated local branch. This authorization includes the required `--force`; do not request separate approval for verified managed cleanup.
- Before Worktrunk cleanup, use `wt list --format=json` and the session's creation receipt to verify the checkout path and branch; a listing or branch name alone is not ownership evidence. From a surviving workspace, use `wt remove <branch> --foreground --format=json` so repository pre-remove hooks stop owned services first. Use force/branch-deletion flags only within the verified cleanup authorization. Close the exact associated Herdr workspace separately after checking its panes; never infer ownership from its label.
- Never remove a worktree and delete its branch in separate Bash calls. If the worktree has already disappeared, its branch ownership cannot be re-established from the branch name; require approval or leave the branch in place.
- Require approval for primary or unknown checkouts. Never remove the default branch, remote branches, or anything explicitly marked user-owned or `keep`. If ownership cannot be verified, leave the path or branch in place and report it rather than working around the guard.
- Before restoring a tracked file to unblock a merge, inspect its diff and establish who owns the changes. Preserve them unless discarding them is authorized under the checkout ownership rules above.
- For exact-SHA detached checkouts, when Worktrunk is unavailable, or when it cannot represent the required checkout, use `git worktree` and the same `.worktrees` default; explicitly run the repository's setup and teardown. Plain Git worktrees are eligible for unattended destructive cleanup only from the session running inside that linked worktree; otherwise require approval or leave cleanup to the harness.
