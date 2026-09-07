---
name: backlog-md
description: Use the Backlog.md CLI or MCP for provider-backed task operations.
---

# Backlog.md

Use `backlog-source-workflow` for source selection, dependencies, claims, refinement, and blockers. This skill supplies Backlog.md-specific mechanics.

- Use the `backlog` CLI or authorized MCP integration; never edit task files directly.
- Before starting implementation, use the primary checkout on `main` to reread the task and set it to `In Progress`; reread it again to confirm the write before creating or using an implementation worktree. This shared state is the claim that prevents another agent from selecting the task.
- Do not select a task already marked `In Progress` unless the caller explicitly assigns or hands it off to you.
- In a Git worktree, read and write all task state from the primary checkout on `main`, never from the worktree branch.
- Prefer `--plain`, read the complete item before changing it, and preserve unknown content.
- Use [the CLI map](references/cli.md). Consult live help only when the installed version rejects a command or a needed operation is absent.
- Reread the item after every write.

Keep implementation tasks, acceptance criteria, and Definition of Done distinct. Preserve checked entries and stable IDs. Use dependencies for required ordering and parents only for grouping. Complete an item only when its observable acceptance and required delivery evidence are satisfied; archive only when requested or established by the provider workflow.
