---
description: Emit compact work-state snapshot
---

Emit a compact, concrete work-state report for a user checking in mid-task.

Use current conversation/tool state first. Run only safe read-only checks when
needed to avoid guessing, such as todo/job/subagent state, branch/PR status, and
changed files. Do not continue implementation, edit files, commit, push, or run
broad validation just to answer status.

Output exactly:

## Work snapshot

- Current task:
- Acceptance criteria:
- Last concrete action:
- Active branch / PR / task:
- Active file area:
- Changed files:
- Open risks / blockers:
- Last verification result / coverage:
- Pending verification:
- Next recommended action:

## Add-on

- Least confident:
- Biggest thing you may be missing:
- Outstanding unrequested idea:

Rules:

- Prefer facts over commentary. Include paths, commands, PR numbers, job IDs,
  failing checks, and test names when observed.
- Mark unobserved fields as `not observed`; never invent state.
- Mark inferred claims with `[INFERENCE]`.
- Keep the add-on short: one sentence per bullet.
- Do not summarize away unfinished acceptance criteria or known failing checks.
