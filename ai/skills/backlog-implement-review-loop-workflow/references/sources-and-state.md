# Sources and State Selection

## Resolve the exact scope

1. Identify every explicit local backlog path, remote backlog reference, item selector, and other path supplied with the invocation.
2. Validate local backlog paths left to right before editing. For a missing path, inspect only adjacent path-like locations: the same directory or an unambiguous same-basename move. Stop if the backlog source cannot be resolved uniquely.
3. Treat other file paths as discovery hints, not presence gates. Report unresolved hints without stopping when the backlog source itself is valid.
4. Preserve source and item order. Never choose a later, easier task while an earlier eligible task remains.

## Pin remote sources

- Resolve remote references through their first-party authenticated tool.
- Fetch exact item text and existing marker comments before work.
- Pin remote text into an existing structurally matching writable backlog entry, a repository-conventional snapshot, or command-local/temporary notes outside the worktree.
- Implement and review the pinned state, not a moving remote description. Refresh the pin and reselect state if the remote item changes.
- Never create repository backlog/spec markdown for a remote-only item merely to store state.

## Determine write authority

- An explicitly named local Markdown backlog is writable.
- A remote item maps to a writable local entry only when exactly one repository Markdown backlog structurally owns that item ID.
- Other remote items are remote-only. Update only statuses or comments expressly authorized by the active workflow; otherwise retain state in the handoff.
- Local Markdown that is context rather than the resolved backlog source is read-only.

## Select one state

Inspect the first scoped item that is open, incomplete, unreviewed, or blocked by a stale/resolved marker:

- `IMPLEMENT`: the first explicit task is incomplete, required behavior is absent/failing, or the work is not traceable to an implementation commit. When there is no task list, select the smallest coherent slice that completes the first unmet acceptance criterion.
- `REVIEW`: every task and acceptance criterion is implemented, an accumulated implementation state exists, and no valid marker names that exact state. Batch other fully implemented, unreviewed items only when their complete diffs and verification can be reviewed safely together.
- `BLOCKED`: a required external product decision, unavailable dependency, or unsafe ambiguity prevents implementation/review after all safe work and one oracle consultation. Missing code, in-scope failures, and outdated tests are work, not blockers.
- `ARCHIVE`: every scoped item is implemented, reviewed, verified, committed, integrated, and has valid final state; only source archival or final remote status remains.

## Marker validity

A `reviewed:` marker is valid only for the exact implementation commit set it names, plus any review-fix commit covered by that same pass. Changes to relevant code, commits, or acceptance criteria invalidate it.

A `blocked:` marker is valid only while its reason, tried path, evidence, and unblock condition match current code, backlog text, dependencies, and verification. New evidence or an available dependency automatically reopens selection.

Use the source's existing marker style. Otherwise use:

```text
reviewed: <implementation-commit(s)> [review-fix: <commit>]; verified: <brief command/result>
blocked: <short reason>; tried: <brief attempted path>; unblock: <specific decision/dependency/evidence needed>
```

## Delegation budget

Work directly for a coherent task, one subsystem, or an already-known scope. Across one pass, use at most two `explore`/`executor` workers plus one oracle consultation. The limit is total, not concurrent; finished workers are not replaced. Never create an agent per file, criterion, test, or review dimension. Perform overflow work directly.
