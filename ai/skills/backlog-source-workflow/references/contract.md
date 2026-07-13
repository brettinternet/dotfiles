# Source workflow contract

This contract is the provider-neutral boundary used by backlog commands. It resolves a source, enumerates work, chooses the next eligible item, and persists provider-owned state. It does not implement an `IMPLEMENT`, `REVIEW`, or `/loop` pass; those remain command responsibilities.

## Normalized values

### `Source`

```text
Source {
  kind: loose-markdown | backlog-md | linear | github-issues | <future-kind>
  locator: provider-native path, project/team identifier, or repository identifier
  name: stable human-readable name
  providerData: opaque provider metadata needed by the selected provider section
}
```

`Source` is a capability and identity, not an authorization grant. A resolved source is read-only until the caller passes explicit authority to a mutation.

### `ItemState`

```text
ItemState {
  source: Source
  id: stable provider ID
  title: string
  body: provider-normalized description
  status: provider-normalized status
  dependencies: stable IDs (and unresolved references when present)
  priority: provider priority or null
  ordinal: source order or null
  review: none | pending | in-progress | complete
  providerData: opaque provider fields and version information
}
```

Do not replace provider fields with a local copy. `status`, `review`, progress comments, task checkboxes, timestamps, and completion markers remain durable in the provider source. For remote providers, any local snapshot/cache is read-only temporary context; it must never become writable shadow backlog state or a fallback mutation target.

### `SchedulingScope`

A scope is separate from both an implementation item and a review boundary:

```text
SchedulingScope {
  sources: ordered Source[]
  items: ordered ItemState[]
  sourceOnly: boolean
  explicitItemIDs: ordered stable IDs[]
  implementationItem: ItemState | null
  reviewGroup: ReviewGroup | null
}
```

When `sourceOnly` is true, `items` is the whole collection returned by `discover` for every resolved source, in explicit source order; it is never a first-item shortcut. An explicit item selector narrows `items` to that selection while retaining selector and source argument order. Dependencies may be read outside that selection to determine readiness, but selecting a dependency never widens implementation scope. Provider priority/ordinal is used only within each source-only collection.

### `ReviewGroup`

```text
ReviewGroup {
  id: stable provider group ID or null
  label: string
  itemIDs: ordered stable IDs[]
  explicit: true
  reason: provider-native milestone, epic, parent, or explicit command selector
}
```

The default review boundary is exactly one implementation item (`itemIDs` contains one ID). A source-only schedule does **not** imply a source-wide review, and a milestone/epic/parent group is used only when the caller explicitly requests it and the provider can resolve and durably persist it. The operational request form is `review-group:<provider-native-selector>`; parse the prefix, pass the remaining selector opaquely to the selected provider, and require the provider to return the exact ordered member IDs. If parsing, resolution, or durable group-marker persistence is unsupported, return an explicit capability/invalid-selector diagnostic; never downgrade to the one-item default, infer a group, or write a local marker. Review reads may inspect the group's members, but review mutation and acceptance must remain inside the authorized group.

## Operations

Commands use these operations for every provider. Provider sections map them to concrete tooling.

1. `resolveSource(arguments, repositoryContext)` returns an ordered `Source[]` plus diagnostics. It must not mutate anything. Explicit source arguments are resolved in supplied order, including unrelated provider kinds.
2. `discover(source, selector?)` returns all matching `ItemState` values, including dependencies needed for graph checks. With no selector it enumerates the complete source collection.
3. `selectNext(scope, mode)` evaluates state and dependency readiness and returns one implementation item, or a structured blocked/empty result. It never returns a review group.
4. `readItem(source, id)` refreshes one durable `ItemState` before a write or review.
5. `writeState(source, id, patch, authority)` records an authorized status, task, review, or progress change and returns a provider receipt (ID/version or equivalent).
6. `recordProgress(source, id, marker, authority)` writes the command's durable checkpoint using the provider's native comment, task-state, checkbox, or field mechanism. A handoff message alone is not a checkpoint.
7. `reviewBoundary(scope, requestedGroup?, authority)` parses an explicit `review-group:<provider-native-selector>`, resolves it through the selected provider, and returns that group; absent a request it returns the one-item default. It must reject an implicit larger group and any provider that cannot persist the requested group marker.
8. `archive(source, target, authority)` uses the provider's archive/close/move convention and returns a durable receipt. It must never delete a source as a substitute for archive.

Every operation must preserve explicit source and selector order and stable IDs. Unsupported provider mutations are an explicit capability error; do not silently edit a neighboring local file, create a local remote shadow, or invent a fallback store.

## Source resolution and detection

Treat arguments as an ordered list and classify explicit source locators, item selectors, and review-group requests before discovery:

1. An explicit provider-qualified source (`linear:...`, `github:...`, a Backlog.md project/task locator, or a future provider qualifier) selects that provider and exact locator.
2. An explicit existing local source path selects the file/project at that path. Validate it as a source before reading items.
3. An explicit provider-native item/project identifier is resolved with its first-party tool. An unqualified identifier that could match more than one provider is ambiguous; do not guess from whichever integration answers first.
4. For an explicit item selector within a resolved source, use exact precedence: stable provider ID first, then exact title, then exact description. A selector is not fuzzy-matched; duplicate matches at the winning level are ambiguous, and a lower-precedence field is not consulted after an ambiguous higher-precedence match.
5. Parse `review-group:<provider-native-selector>` as an explicit group request, preserving the provider-native selector unchanged for `reviewBoundary`; it is not an item selector or an implicit source-wide group.

Resolve every explicit source in supplied order, including sources from unrelated providers. If any explicit source was supplied, repository-derived detection is forbidden, even when an explicit source fails. A missing explicit local path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate; report the original path, the substituted candidate, and the diagnostic. If no single candidate is clear, report the explicit failure and do not fall back to another or derived source. If no explicit source was supplied, inspect repository context for provider markers and conventional loose-Markdown sources; accept exactly one candidate or return a missing/ambiguous-source diagnostic with candidate paths or provider locators.

After each source kind is known, load only that provider's matching section from the skill references, in preserved source order. Do not query remote providers or parse unrelated local formats before selection.

## Eligibility, dependencies, and scheduling

Build a dependency graph over the selected collection. For each item:

- A dependency is ready only when its durable provider state is complete, closed, archived, or the provider's equivalent terminal state.
- A missing dependency ID/reference is a blocking diagnostic on the dependent item. It is not treated as complete and is not silently removed from the graph.
- A directed cycle is a blocking diagnostic for every member of the cycle. Detect cycles (for example, strongly connected components) before choosing work; do not break a cycle by arbitrary order.
- A dependency outside an explicit item selection may be read from the same provider to establish terminal state, but its implementation remains outside the scope.
- Items explicitly blocked by provider state, missing dependencies, or cycles are ineligible and must remain visible in the result.

Dependency readiness is a hard gate. After blocked items, if `explicitItemIDs` is non-empty, choose the first dependency-ready item in preserved source and selector order; do not reorder it by provider priority or ordinal. For a source-only scope, preserve explicit source order across sources, then within each source choose review-pending/in-progress work that the caller's mode can advance, then other dependency-ready work, then provider priority, ordinal/source order, and stable ID. Preserve source order when no provider priority exists. A provider's display order must not override a dependency block.

## Durable state and authority

The caller supplies an authority object describing allowed reads, writes, reviews, archive operations, and the exact command scope. Pass it unchanged to mutations. Resolution and discovery cannot expand it. A source-only invocation may enumerate the whole source, but it may write only the item/group authorized by the command; it may not turn enumeration into a source-wide review or rewrite.

Read current durable state immediately before a mutation where the provider can change concurrently. Write through the selected provider and retain its receipt/version. If a write fails, report the durable failure and do not claim the task or review complete. Persist each command-defined checkpoint (including progress, blocked, review, and completion state) in the provider source before advancing. Remote provider state remains authoritative; local snapshots are read-only temporary context and never a writable shadow or fallback state. Do not use handoff text as durable state.

Archive is a provider operation, not a scheduling decision. It is allowed only when the caller authorizes it and the provider section defines the operation. Closing a GitHub issue, archiving a Linear item, archiving a Backlog.md task, or moving an existing loose-Markdown source to its established archive location must be recorded with the provider receipt.

## Provider extension rule

A future provider adds one provider section that implements source detection, complete discovery, normalized status/dependency/order mapping, durable read/write/progress, review-boundary resolution, and archive. It may retain opaque fields in `providerData`, but it must not change these normalized values, selection precedence, default one-item review boundary, or command call sites. If a capability is unavailable, return a structured capability error rather than changing the contract.
