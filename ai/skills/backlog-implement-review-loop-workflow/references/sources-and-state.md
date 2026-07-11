# Sources and State Selection

## Resolve the exact scope

1. Identify every explicit local backlog path, remote backlog reference, item selector, and other path supplied with the invocation.
2. Validate local backlog paths left to right before editing. For a missing path, inspect only adjacent path-like locations: the same directory or an unambiguous same-basename move. Stop if the backlog source cannot be resolved uniquely.
3. Treat other file paths as discovery hints, not presence gates. Report unresolved hints without stopping when the backlog source itself is valid.
4. Preserve source and item order. Never choose a later, easier task while an earlier eligible task remains.

## Pin remote sources

- Resolve remote references through their first-party authenticated tool.
- Fetch exact item text and existing `implemented:`, `reviewed:`, and `blocked:` comments before work.
- Pin remote text into an existing structurally matching writable backlog entry, a repository-conventional snapshot, or command-local/temporary notes outside the worktree. Handoff is not a durable backlog source.
- Implement and review the pinned state, not a moving remote description. Refresh the pin and reselect state if the remote item changes.
- Never create repository backlog/spec markdown for a remote-only item merely to store state.

## Determine write authority

- An explicitly named local Markdown backlog is writable.
- A remote item maps to a writable local entry only when exactly one repository Markdown backlog structurally owns that item ID.
- Other remote items are remote-only. The active workflow authorizes `implemented:`, `reviewed:`, and `blocked:` item comments plus the final done/merged transition. If required comment write-back is unavailable or fails, do not begin or complete a multi-pass state in handoff alone.
- Local Markdown that is context rather than the resolved backlog source is read-only.

## Select one state

Inspect the first scoped item that is open, incomplete, unreviewed, or blocked by a stale/resolved marker:

- `IMPLEMENT`: select exactly the first explicit open task. A refined task is the pass boundary and includes inseparable production code, required callsites, fixtures/migrations, and proving tests. If a writable local item has no explicit tasks or its first task contains multiple independently useful behaviors, split it into named ordered tasks, map all acceptance criteria, and commit that refinement before coding. For a remote-only unrefined or oversized item, stop and invoke `backlog-refine`. Never select an unnamed internal slice.
- `REVIEW`: every task and acceptance criterion is implemented, an accumulated implementation state exists, and no valid marker names that exact state. Batch other fully implemented, unreviewed items only when their complete diffs and verification can be reviewed safely together.
- `BLOCKED`: a required external product decision, unavailable dependency, or unsafe ambiguity prevents implementation/review after all safe work and one oracle consultation. Missing code, in-scope failures, and outdated tests are work, not blockers.
- `ARCHIVE`: every scoped item is implemented, reviewed, verified, committed, integrated, and has valid final state; only source archival or final remote status remains.

## Durable progress

The writable backlog item is authoritative for local sources; remote item comments are authoritative for remote-only sources. Before ending a pass, persist the current status, completed task and implementation commit, exact verification result, exact next task or review state, and remaining acceptance criteria. If the source has no established style, use:

```text
implemented: <task>; commit: <commit>; verified: <command/result>; status: <in-progress|review-pending>; next: <task|REVIEW>; remaining: <acceptance criteria|none>
```

Commit local progress state. Post the same line as a remote-only item comment. If durable write-back fails, do not claim the pass complete; retain the coherent implementation commit and make state repair the next action.

## Marker validity

A `reviewed:` marker is valid only for the exact implementation commit set it names, plus any review-fix commit covered by that same pass. Changes to relevant code, commits, or acceptance criteria invalidate it.

A `blocked:` marker is valid only while its reason, tried path, evidence, and unblock condition match current code, backlog text, dependencies, and verification. New evidence or an available dependency automatically reopens selection.

Use the source's existing marker style. Otherwise use:

```text
status: complete; remaining: none; reviewed: <implementation-commit(s)> [review-fix: <commit>]; verified: <brief command/result>
status: blocked; blocked: <short reason>; tried: <brief attempted path>; unblock: <specific decision/dependency/evidence needed>; remaining: <acceptance criteria>
```

Handoff-only `implemented:`, `reviewed:`, or `blocked:` markers are invalid. A remote marker write failure leaves the corresponding pass incomplete; it must not cause a later pass to skip or complete the item.

## Delegation budget

Work directly for a coherent task, one subsystem, or an already-known scope. Across one pass, use at most two `explore`/`executor` workers plus one oracle consultation. The limit is total, not concurrent; finished workers are not replaced. Never create an agent per file, criterion, test, or review dimension. Perform overflow work directly.
