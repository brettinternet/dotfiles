---
name: backlog-md
description: Use when working with a Backlog.md project or its `backlog` CLI/MCP, including creating, reading, refining, updating, completing, or archiving tasks and managing dependencies or milestones.
---

# Backlog.md

Treat Backlog.md as a provider-owned task system. Use `backlog-source-workflow` for source selection, dependency scheduling, and claims; use this skill for provider operations and ticket conventions.

## Provider rules

- Use the `backlog` CLI or authorized MCP integration. Never edit its task files directly.
- In a Git worktree, run provider reads and writes from the primary/control checkout; implementation worktrees contain code only.
- Prefer `--plain` for agent-readable output and read the complete item before editing it.
- Use [`references/cli.md`](references/cli.md) as the command map. Consult narrow live help only when the installed version rejects a command or a needed capability is missing.
- If the CLI is unavailable, use authorized MCP or report the limitation. Use `bunx backlog.md` only when one-off dependency execution is authorized.
- Preserve unknown content and reread after writing.

## Ticket shape

Keep implementation tasks, acceptance criteria, and Definition of Done distinct:

```markdown
### Implementation tasks
- [ ] T1 — one coherent behavioral outcome

### Acceptance criteria
- [ ] AC1 — observable behavior or contract

### Definition of Done
- [ ] DOD1 — final verification or delivery obligation
```

Implementation tasks are the work sequence. Acceptance criteria describe testable outcomes. Definition of Done is a final quality gate. Preserve checked entries and stable IDs; never reset them without evidence that work was reopened.

Use native Backlog.md plan, AC, and DoD fields. The CLI supports AC/DoD checkbox operations; update the complete plan field when changing a plan checkbox. A checked task records progress but does not by itself complete the provider item.

When creating or refining tickets, use dependencies for required order and parents only for genuine grouping. Split into separate tasks only for independently deliverable outcomes or useful parallelism; otherwise keep one item with bounded implementation tasks.

Complete an item only after its tasks and acceptance criteria are satisfied and required verification/review evidence is recorded. Archive only when requested or required by the project's established workflow.
