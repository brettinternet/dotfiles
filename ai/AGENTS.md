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

## Git

- Never run `git push` without explicit instruction.
- Never open PRs without explicit instruction.
- When committing, do not add yourself as a co-author. Omit any `Co-Authored-By` trailer. Make commit messages as concise as possible.
