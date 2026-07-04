Finish `$ARGUMENTS` or, if empty, the current task. Leave the repo in a clean,
committed state when completion is possible, then provide a copy-pasteable prompt
for the next recommended work item.

Treat `$ARGUMENTS` as the exact scope. Do not expand into unrelated cleanup,
nearby backlog items, or opportunistic refactors.

Before finishing:

1. Establish the current goal, acceptance criteria, active branch, and changed
   files.
2. Separate task-related changes from unrelated user work. Preserve unrelated
   unstaged or untracked files.
3. Identify what is already complete, what still needs implementation, and any
   blocker that prevents completion.

Finish the work:

1. Complete only the scoped task or current task.
2. Update required tests, docs, generated files, migrations, or configs that are
   directly part of the task.
3. Remove obsolete scaffolding, debug code, TODOs, stale shims, and dead paths
   created by this work.
4. Run the smallest verification loop that proves the completed behavior:
   targeted tests, typecheck, lint, format check, build, migration check, browser
   QA, or manual scenario as appropriate.
5. Run formatting and linting that applies to the edited files or project
   conventions. Do not claim project-wide health unless project-wide checks ran.
6. Commit only task-related changes with a concise message. Do not push.

If completion is blocked:

- Do not claim the task is done.
- Commit only if the committed state is coherent and useful; otherwise leave the
  worktree uncommitted and explain why.
- State the exact missing decision, failing check, unavailable dependency, or
  unfinished acceptance criterion.

Final response must be a transition artifact, not a recap. Output exactly:

`HANDOFF READY` or `HANDOFF BLOCKED`

## Transition snapshot

- Current task:
- Acceptance criteria:
- Last concrete action:
- Active branch / commit:
- Changed files:
- Verification:
- Remaining work:
- Risks / blockers:
- Next recommended action:

## Next-agent prompt

Provide a copy-pasteable prompt for the next agent. Include:

- current repo/branch state
- what was completed and committed
- exact next recommended work item
- files, commands, tests, and context to inspect first
- known risks, blockers, failed checks, and verification already run
- explicit non-goals

Rules:

- Use `HANDOFF READY` only when the scoped work is complete, verified, and
  committed.
- Use `HANDOFF BLOCKED` when any required acceptance criterion, verification,
  decision, or commit remains incomplete.
- Mark unobserved details as `not observed`; do not invent state.
