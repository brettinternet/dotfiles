---
name: backlog-source-workflow
description: Resolve and operate on backlog sources consistently across loose Markdown, Backlog.md, GitHub Issues, Linear, and other supported providers. Use whenever a backlog command or skill reads or changes provider-backed work.
---

# Backlog Source Workflow

Keep the user's backlog authoritative. This skill supplies the shared source, scheduling, and coordination rules; the calling command or skill supplies intent and mutation authority.

## Resolve the source

1. Resolve explicit sources before selectors and preserve argument order. Never silently replace an unresolved explicit source or merge unrelated sources.
2. Without an explicit source, use repository configuration or discover exactly one plausible backlog. Ask when several are equally plausible.
3. Resolve selectors by stable provider ID, then exact title, then exact description. Do not fuzzy-match ambiguity away.
4. Use the provider's supported interface:
   - loose Markdown: preserve its existing structure and vocabulary
   - Backlog.md: use `backlog` CLI/MCP; never edit task files directly
   - GitHub Issues: use `gh`
   - Linear or another remote provider: use its authenticated first-party integration
5. For Backlog.md in a Git worktree, read and write provider state from the primary/control checkout. Implementation worktrees contain code only.

Source-only input means the whole collection for scheduling, not permission to mutate every item or review the whole collection.

## Select work

Read enough of the collection to understand status, dependencies, blockers, progress, review state, and active Worklease claims.

- Prerequisites must finish before dependents. An unfinished defined prerequisite is `ready after <item>`, not blocked.
- Prefer resumable in-progress or review-pending work before new work in the same ready wave.
- Multiple agents may take independent, unclaimed items from the same ready wave.
- An active claim means wait or choose another independent item; never steal it or skip to its dependent.
- Mark work blocked only for a real external/human dependency, an explicit provider blocker, or an unresolved missing/cyclic dependency. Ordinary implementation difficulty and failing tests are not blockers.
- Review one item by default. Review several only when the caller explicitly identifies that group.

## Coordinate mutations

Before editing code or provider state for an item, use `worklease-workflow` to claim one canonical item resource derived from the provider, source, and item. Implementation, review, and unblock work use that same resource so they cannot overlap. Loose Markdown may require a source-wide claim.

While holding the claim:

1. Refresh the item and dependencies before consequential writes.
2. Heartbeat around long operations.
3. Record useful durable progress in the provider: completed task, commit or PR, verification, next step, review result, or precise blocker and unblock condition.
4. Verify that checkpoint from the authoritative source, then release the claim.

Use the strongest mutation guard actually available. `worklease replace-file` can guard a loose Markdown replacement with an expected hash; remote CLI/API writes are normally same-host coordination only. Do not describe assignment, status, comments, branches, or a local lease as provider-side or cross-host fencing.

If a write or claim outcome is ambiguous, reread the claim and provider state before retrying. Never create a writable local shadow for a remote provider.

## Item progress

When an item needs implementation decomposition, prefer a stable item-local checklist:

```markdown
### Implementation tasks
- [ ] T1 — Add the parser
- [ ] T2 — Update callers
```

Treat these as progress within one provider item, not separately scheduled backlog items. Preserve checked tasks. A missing checklist is not itself a blocker when the next bounded task is otherwise clear.
