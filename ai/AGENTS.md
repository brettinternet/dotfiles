@AGENTS.local.md

# User Preferences

## Communication Style

- Be terse and direct. Skip preamble, filler phrases, and trailing summaries.
- Lead with the answer or action, not the reasoning.
- Use plain text over bullet lists when a sentence suffices.

## Tools

- Use `gh` CLI for all GitHub operations. Never construct raw API calls or open browser URLs.
- Use `mise exec <tool> -- <cmd>` when a tool is installed via mise and may not be in PATH.
- Use `chrome-devtools` tool to verify browser changes when working with web UI.
- Prefer fast local CLIs for code navigation: use `rg`/ripgrep for content search, `fd` for file discovery, and `ast-grep` for structural code search/refactors before falling back to fragile regex edits.

## Git

- Never run `git push` without explicit instruction.
- Never open PRs without explicit instruction.
- When committing, do not add yourself as a co-author. Omit any `Co-Authored-By` trailer. Make commit messages as concise as possible.
