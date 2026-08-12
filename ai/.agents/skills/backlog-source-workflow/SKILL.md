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
5. For Backlog.md in a Git worktree, read and write provider state from the primary/control checkout.

Source-only input means the whole collection for scheduling, not permission to mutate every item or review the whole collection.

## Select work

Read enough of the collection to understand status, dependencies, blockers, progress, review state, and active claims.

- Prerequisites must finish before dependents. An unfinished defined prerequisite is `ready after <item>`, not blocked.
- Prefer resumable in-progress or review-pending work before new work in the same ready wave.
- Multiple agents may take independent, unclaimed items from the same ready wave.
- An active claim means wait or choose another independent item; never steal it or skip to its dependent.
- Mark work blocked only for a real external/human dependency, an explicit provider blocker, or an unresolved missing/cyclic dependency. Ordinary implementation difficulty and failing tests are not blockers.
- Review one item by default. Review several only when the caller explicitly identifies that group.

## Coordinate mutations

Before editing code or provider state for an item, use provider-native claims or concurrency controls when available.

During mutation:

1. Refresh the item and dependencies before consequential writes.
2. Record useful durable progress in the provider: completed task, commit or PR, verification, next step, review result, or precise blocker and unblock condition.
3. Verify that checkpoint from the authoritative source.

If a write or claim outcome is ambiguous, reread the claim and provider state before retrying. Never create a writable local shadow for a remote provider.

## Item progress

When an item needs implementation decomposition, prefer a stable item-local checklist:

```markdown
### Implementation tasks
- [ ] T1 — Add the parser
- [ ] T2 — Update callers
```

Treat these as progress within one provider item, not separately scheduled backlog items. Preserve checked tasks. A missing checklist is not itself a blocker when the next bounded task is otherwise clear.
