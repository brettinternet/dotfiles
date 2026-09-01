---
name: backlog-md
description: Use the Backlog.md CLI or MCP for provider-backed task operations.
---

# Backlog.md

Use `backlog-source-workflow` for source selection, dependencies, claims, refinement, and blockers. This skill supplies Backlog.md-specific mechanics.

- Use the `backlog` CLI or authorized MCP integration; never edit task files directly.
- In a Git worktree, read and write task state from the primary checkout.
- Prefer `--plain`, read the complete item before changing it, and preserve unknown content.
- Use [the CLI map](references/cli.md). Consult live help only when the installed version rejects a command or a needed operation is absent.
- Reread the item after every write.

Keep implementation tasks, acceptance criteria, and Definition of Done distinct. Preserve checked entries and stable IDs. Use dependencies for required ordering and parents only for grouping. Complete an item only when its observable acceptance and required delivery evidence are satisfied; archive only when requested or established by the provider workflow.
