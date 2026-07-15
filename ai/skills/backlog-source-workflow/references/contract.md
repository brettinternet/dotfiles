# Source Workflow Contract

This is the provider-neutral boundary for backlog workflows. It resolves, discovers, schedules, and persists provider-owned state; the caller supplies mode, scope, and authority.

## Normalized values

```text
Source { kind, locator, name, providerData }
ItemState {
  source, id, title, body, status, dependencies, priority, ordinal,
  refinement: none | in-progress | complete,
  review: none | pending | in-progress | complete,
  claim: WorkClaim | null, providerData
}
SchedulingScope {
  sources, items, sourceOnly, explicitItemIDs,
  implementationItem: ItemState | null,
  reviewGroup: ReviewGroup | null
}
WorkClaim {
  targetID, resource, authority: provider-native | local-host,
  guarantee: fenced | local-coordination,
  workKey, mode, workflow, claimID, revision,
  agentID, ownerID, sessionID, token,
  startedAt, heartbeatAt, expiresAt
}
ReviewGroup { id, label, itemIDs, explicit: true, reason }
```

`providerData` retains opaque provider identity/version fields. Provider status, dependencies, progress, review, and completion remain authoritative; local snapshots are temporary read-only context.

For a repository-backed provider, `providerData` also retains its canonical provider execution context. A Backlog.md source named from any Git worktree resolves its repository-relative location against the repository's unambiguous primary/control checkout; its canonical locator and every provider read/write use that checkout. Implementation worktrees contain code changes only and must not become alternate provider authorities. If the control checkout cannot be identified safely, the mapped source is absent, or its provider state is unsafe to mutate, return `WAIT`/a capability diagnostic instead of reading, writing, or falling back through the caller's feature worktree.

A claim is one bounded ownership epoch, separate from durable `in-progress` state. Worklease's `fenced` guarantee covers only the named guarded local operation on this host; a provider CLI or remote API remains `local-coordination` unless the provider mutation itself supplies conditional-write/fencing evidence. Read [`claims.md`](claims.md) before claim operations or claimed writes.

`ReviewGroup` exists only for an explicit `review-group:<provider-native-selector>`. The provider must resolve exact ordered members and persist its authorized marker. Otherwise return a capability/invalid-selector diagnostic. Without that token, the review boundary is exactly one implementation item; source-only scope never implies group review.

## Source resolution and scope

Classify the ordered arguments before discovery:

1. Resolve provider-qualified sources, existing local source paths, and exact provider-native identifiers with their selected tooling. The canonical provider-qualified form is `<provider>:<locator>` (for example, `linear:TICK`). Also accept a case-insensitive provider name followed by the next argument token, or one quoted multiword argument, as the same explicit source (for example, `Linear TICK`); consume the qualifier and locator before parsing any remaining selectors. A recognized provider qualifier always makes the reference explicit: resolve unique exact provider-native identity matches before broader name or description search, and never let a partial/fuzzy search result compete with an exact match. If the locator or integration cannot resolve, report that remote reference as unresolved rather than treating the arguments as selector-only or source-free. Repository context and derived-source detection cannot reinterpret, constrain, or disambiguate a provider-qualified source.
2. Resolve item selectors within the immediately preceding source by stable ID, then exact title, then exact description. Stop on ambiguity at the first matching precedence level; do not fuzzy-match.
3. Preserve every explicit source and selector in supplied order, including unrelated provider kinds. Provider priority never reorders sources.
4. If any explicit source was supplied, never fall back to repository-derived detection. A missing local path may substitute one clearly adjacent same-directory or moved/renamed-basename candidate only; report both paths. Otherwise fail that source.
5. Without an explicit source, accept repository-derived detection only when exactly one candidate remains; report missing/ambiguous candidates otherwise.
6. For Backlog.md inside a Git worktree, preserve the supplied source for diagnostics but canonicalize provider identity and execution to the same repository-relative source in the primary/control checkout. All later discovery, refresh, mutation, and receipt verification use that context, including when the caller runs from an implementation worktree.

A source-only scope contains the complete discovered collection for every resolved source, never only the first actionable item. Explicit selectors narrow mutation scope but may still require reading dependencies outside the selection. Reading a dependency never authorizes mutating it. When the caller explicitly grants decomposition authority, provider items derived from a selected item join mutation and scheduling scope at creation; existing unselected items remain read-only and may only be referenced as relationship targets.

After resolving each kind, load only its provider section.

## Dependencies and scheduling

Build the complete dependency graph before selection or delegation. Detect missing targets and cycles; never break them by arbitrary ordering.

- Implementation/review requires every prerequisite to be provider-terminal. `in-progress` is incomplete.
- Refinement proceeds in topological waves. A dependent may enter a later wave only after its prerequisite's authorized specification write and durable, discoverable `refinement: complete` checkpoint. Claim release alone is insufficient.
- An incomplete defined prerequisite is dependency-gated and may be reported `ready after <item>`; never persist it as blocked for that reason.
- `blocked` is reserved for provider-authored blockers, missing/cyclic dependency diagnostics, or evidence-backed external/human decisions authorized by the caller.
- Active item/source claims exclude their covered work and unfinished dependents. Unclaimed resumable work and expired-claim work rank before new work in the same ready wave.

After hard gates, explicit selections use source/selector order. Source-only selections use source order, dependency wave, caller-advanceable resumable work, then provider priority/ordinal/stable ID. Multiple workers may take only independent items from the same ready wave.

When nothing is claimable, return structured state:

- `complete`: all scoped work is terminal
- `blocked`: every unfinished root has a genuine blocker above
- `active-claims`: otherwise-progressable roots are leased, including owners, expiries, and gated dependency chains
- dependency-gated: unfinished work waits on defined prerequisites; do not skip ahead or mislabel it blocked

## Operations

All operations preserve stable IDs, explicit order, scope, and caller authority.

1. `resolveSource(arguments, repositoryContext)` returns ordered sources plus diagnostics without mutation.
2. `discover(source, selector?)` returns matching items and dependencies needed for graph checks; no selector means the whole collection.
3. `selectNext(scope, mode)` returns one ordered eligible item or structured no-work state.
4. `selectWave(scope, mode)` returns only the current ordered dependency-ready, unclaimed wave; callers may narrow but never add later items.
5. `readItem(source, id)` refreshes durable state before claim, write, or review.
6. `claim(source, id, request, authority)` atomically acquires absent/expired ownership and returns claim/receipt or `busy | ineligible | conflict | capability`.
7. `heartbeat(...)` extends only the matching unexpired claim and returns its new revision/receipt.
8. `releaseClaim(...)` removes only the matching unexpired claim after a durable checkpoint and non-blank reason.
9. `createItem(source, specification, relationships, authority)` creates one provider item only when the caller explicitly authorizes decomposition or item creation, preserving a returned stable ID and provider receipt. Relationship targets must already exist or be created earlier in the same guarded decomposition epoch.
10. `writeState(...)` applies one authorized provider patch, including authorized parent/dependency relationships, through the selected fenced or coordination-only path and returns a provider receipt.
11. `recordProgress(...)` writes the caller's durable checkpoint; chat/handoff/claim release is not progress.
12. `reviewBoundary(scope, requestedGroup?, authority)` returns the one-item default or resolves the explicit provider group; never infers a larger group.
13. `archive(...)` uses the authorized provider archive/close/move convention under a matching claim and returns a durable receipt; it never deletes as a substitute.

Creation never follows from discovery alone. A caller with decomposition authority may create items only within a selected item's existing product scope, then must reread every created or rewritten item, validate the resulting acyclic graph and acceptance-criterion ownership, and retain receipts before expanding its in-memory refinement scope. A failed creation or relationship write stops the split; reconcile durable partial results under the same authority rather than deleting them, creating replacements, or advancing dependents.

Repository-backed provider mutations additionally use a short same-host Worklease transaction claim. It is distinct from `WorkClaim`: the item claim owns one pass, while the transaction resource serializes shared provider writes, provider-file commits, and Git integration against the canonical control checkout. Derive one exact `local:provider-transaction:<canonical-common-dir>` resource from the canonical absolute Git common directory (`git rev-parse --git-common-dir` resolved to a real path), acquire it with `--coordination-only` only around the mutation with a finite wait, revalidate the item claim immediately before acquisition, run `worklease exec --git-primary` with that transaction claim (inside the item's guarded command when a long operation must retain the outer lease), reread the item/provider state immediately after, and release it immediately. Never hold the transaction claim during inspection, coding, tests, or review. This is local coordination only and supplies no provider-side or cross-host fence.

## Durable state and authority

Pass the caller's authority unchanged to every mutation. Enumeration never expands scope. Refresh provider state immediately before concurrent-sensitive writes, preserve unrelated fields, retain provider versions/receipts, and verify durable checkpoints before advancing. Failure or ambiguity leaves work incomplete and stops dependents until reconciled.

Claims are the second hard gate after dependencies. Use provider-native fencing only when the provider itself rejects stale writers; otherwise use Worklease item/source claims and report the actual guarantee scope. `worklease replace-file` may fence the exact expected-hash local file replacement; Worklease-guarded provider CLI/MCP calls remain `local-coordination` unless the provider supplies conditional-write evidence. Use capability `none` only when required provider operations, the canonical provider execution context, or a canonical same-host Worklease resource are unavailable. Never downgrade to assignment, status, comments, branches, handoffs, or ordinary locks.

Revalidate dependencies before delegation, integration, and checkpoints. If ownership, provider version, eligibility, or dependencies change, stop; checkpoint only safe authorized resumable state and release when possible. Persist the caller-defined specification/task/review/archive checkpoint under valid ownership before release. Do not advance scheduling after a failed checkpoint or release.

Archive only when the caller authorizes it and the provider section defines it. A future provider implements this contract in one provider section; unavailable operations return structured capability errors rather than changing normalized semantics.
