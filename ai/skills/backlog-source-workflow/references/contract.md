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
  refinement: none | in-progress | complete
  review: none | pending | in-progress | complete
  claim: WorkClaim | null
  providerData: opaque provider fields and version information
}
```

Do not replace provider fields with a local copy. `status`, `review`, progress comments, task checkboxes, timestamps, and completion markers remain durable in the provider source. For remote providers, any local snapshot/cache is read-only temporary context; it must never become writable shadow backlog state or a fallback mutation target.

### `WorkClaim`

```text
WorkClaim {
  targetID: stable item ID or source locator for a source-wide claim
  resource: coordination-authority resource key
  authority: provider-native | local-host
  workKey: exact refinement item, implementation task, review pass, or archive pass
  mode: REFINE | IMPLEMENT | REVIEW | ARCHIVE
  command: claiming command
  claimID: unique ownership-epoch ID
  revision: coordination compare-and-set revision
  agentID: agent identity
  ownerID: unique logical worker-attempt identity
  sessionID: current invocation/session identity
  token: opaque fencing token
  startedAt: coordination-authority timestamp
  heartbeatAt: coordination-authority timestamp
  expiresAt: coordination-authority timestamp
}
```

A claim is a durable, bounded lease, not an ordinary `in-progress` marker. `in-progress` records resumable workflow progress; a claim records one active ownership epoch. A new session may immediately resume unclaimed work and may atomically replace an expired claim without resetting progress, but even the same agent name or a restarted session cannot adopt or renew an unexpired claim. A handoff after a coherent checkpoint releases the claim so the next session need not wait for expiry.

### Claim authority

Claims may use provider-native fencing or the repository's same-host `backlog-claim` service. The local service stores coordination only—never provider status, progress, dependencies, review, or completion—in `BACKLOG_CLAIM_HOME` when set, otherwise `$XDG_STATE_HOME/backlog-work-claims` with `XDG_STATE_HOME` defaulting to `~/.local/state`. It combines one non-blocking OS lock per resource with SQLite compare-and-set state. Every worktree derives the same local-source resource from the common Git directory; GitHub uses canonical host/repository/issue identity. This coordinates only agents running as the same user on one host. Cross-host workers require an authorized shared CAS service and otherwise have capability `none`.

Use `backlog-claim key --provider <backlog-md|github|markdown|linear> --source <locator> --item <id>` to derive the resource. `linear` intentionally returns `unsupported-provider-claim`. Loose Markdown always returns one `source-claim` key for the entire authoritative source; Backlog.md and GitHub return item keys. Generate globally unique claim, session, worker-attempt, and operation IDs. `acquire` defaults to a 900-second lease and rejects TTLs above 3600 seconds; retain its token/revision receipt. Reuse an operation ID only to recover the exact same request's lost response; changed inputs are a conflict. `exec` holds the local resource fence and renews while one `backlog` or `gh` mutation runs. `replace-file` is the only claimed loose-Markdown write path and requires expected source SHA-256. `release` requires a non-blank durable-checkpoint reason. Direct claimed edits are forbidden.

An assignee, label, comment, status, branch, worktree, handoff, or ordinary lock file remains visibility only. Backlog.md projects additionally project the current agent with `backlog task edit <id> -a @<assignee>` under `backlog-claim exec`; that assignment is not the claim and never controls scheduling. Every provider write under a local claim must run through `exec`, or through `replace-file` for loose Markdown, with the current claim ID/token/revision. A stale token, expired lease, version conflict, guarded resource, failed command, or ambiguous receipt stops work. Never bypass the helper with a direct provider/file mutation.

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
3. `selectNext(scope, mode)` evaluates terminal state, dependency readiness, blockers, and claims and returns one ordered claimable item or a structured `complete`, `blocked`, or `active-claims` result. It never returns a review group.
4. `selectWave(scope, mode)` returns the ordered dependency-ready, unclaimed wave available for bounded caller orchestration. The caller may narrow that wave for shared-resource conflicts but must not add later or dependency-gated items.
5. `readItem(source, id)` refreshes one durable `ItemState` before a claim, write, or review.
6. `claim(source, id, request, authority)` atomically acquires an absent/expired claim in the selected authority. `request` includes a caller-generated claim ID, work key, mode, agent/session/owner IDs, bounded TTL, and the caller's freshly validated eligibility receipt. A provider-native authority may revalidate provider eligibility in the same transaction; a local-host authority requires the caller to refresh provider eligibility again after acquisition. It returns the claim, token, authority time, and receipt, or `busy | ineligible | conflict | capability`.
7. `heartbeat(source, id, claimID, token, revision, lease, authority)` conditionally extends only that matching unexpired ownership epoch and returns its new revision/receipt. A selected local-host adapter maps this to `backlog-claim heartbeat`.
8. `releaseClaim(source, id, claimID, token, revision, reason, authority)` conditionally removes only that matching unexpired ownership epoch after its durable checkpoint and returns a receipt. A selected local-host adapter maps this to `backlog-claim release`.
9. `writeState(source, id, patch, authority, claimID?, token?, revision?)` records an authorized status, task, review, or progress change and returns a provider receipt. Under a local-host claim, run exactly one `backlog` or `gh` mutation through `backlog-claim exec`, or one loose-Markdown CAS through `backlog-claim replace-file`; each successful guarded operation advances the claim revision.
10. `recordProgress(source, id, marker, authority, claimID?, token?, revision?)` writes the command's durable checkpoint using the provider's native mechanism. A handoff alone is not a checkpoint. Local-host claimed writes use the same guarded paths as `writeState`.
11. `reviewBoundary(scope, requestedGroup?, authority)` parses an explicit `review-group:<provider-native-selector>`, resolves it through the selected provider, and returns that group; absent a request it returns the one-item default. It must reject an implicit larger group and any provider that cannot persist the requested group marker.
12. `archive(source, target, authority, claimID?, token?, revision?)` uses the provider's archive/close/move convention and returns a durable receipt. Claimed archive work requires the matching unexpired ownership epoch and guarded provider mutation. It must never delete a source as a substitute for archive.

Every operation preserves explicit source/selector order and stable IDs. Adapters declare `item-claim`, fenced `source-claim`, or `none`; partial acquire-only or unfenced write support is `none`. The same-host helper supplies `item-claim` for Backlog.md CLI and GitHub CLI, fenced `source-claim` for loose Markdown through `replace-file`, and `none` for Linear or any mutation that cannot execute inside its fence. Unsupported mutations return explicit capability errors; never invent a second sidecar, direct-edit escape hatch, remote shadow, or racy fallback.

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

Build the complete dependency graph before choosing or delegating work. Dependency ordering is authoritative for every provider and every scheduling mode:

- A dependency is implementation/review ready only when its durable provider state is complete, closed, archived, or the provider's equivalent terminal state. An `in-progress` dependency remains incomplete.
- Refinement may cover incomplete dependents, but only in topological waves. A prerequisite enters `refinement: complete` only after its authorized specification write and durable, discoverable refinement-complete receipt/checkpoint are visible in provider state. Dependents cannot enter a later refinement wave before that barrier, and claim release alone never satisfies it. This refinement completion does not make the dependent implementation-ready.
- A missing dependency ID/reference is a blocking diagnostic on the dependent item. It is not treated as complete and is not silently removed from the graph.
- A directed cycle is a blocking diagnostic for every member of the cycle. Detect cycles (for example, strongly connected components) before choosing work; do not break a cycle by arbitrary order.
- A dependency outside an explicit item selection may be read to establish terminal state or its already-refined contract, but its implementation or specification mutation remains outside scope.
- Items explicitly blocked by provider state, missing dependencies, or cycles are ineligible and must remain visible in the result.

Claims are a second hard gate after dependency readiness. Exclude every item covered by an unexpired item/source claim, regardless of matching agent/session labels. An unfinished dependent of an actively claimed prerequisite remains dependency-ineligible; do not skip the prerequisite and start the dependent. Unclaimed in-progress work and work with an expired claim are resumable and rank before new work in the same dependency-ready ordering wave.

After those gates, if `explicitItemIDs` is non-empty, choose in preserved source and selector order; do not reorder by provider priority or ordinal. For source-only scope, preserve explicit source order, then dependency waves within each source, then resumable review-pending/in-progress work the caller's mode can advance, then other work by provider priority, ordinal/source order, and stable ID. Multiple agents may claim different items only from the same dependency-ready wave. A provider's display order never overrides a dependency edge.

When no item is claimable, return the reason rather than reaching past the gate: `complete` when all scoped work is terminal, `blocked` with every blocker when unfinished work has no satisfiable ready root, or `active-claims` with the active claim owners/expiry and dependency chains they hold when all otherwise-progressable roots are leased. Mixed blocked/claimed results report both. Never select a completed item, a dependent of unfinished work, or a later item merely to avoid returning no work.

## Durable state and authority

The caller supplies an authority object describing allowed reads, claims, writes, reviews, archive operations, and exact command scope. Pass it unchanged to mutations. Resolution/discovery cannot expand it. Source-only scope may enumerate the whole source and claim only the item or dependency-ready wave authorized by the command; it may not turn enumeration into a source-wide review/rewrite or claim later dependency waves.

Read current durable state immediately before a mutation where the provider can change concurrently. Write through the selected provider and retain its receipt/version. If a write fails, report the durable failure and do not claim the task or review complete. Persist each command-defined checkpoint (including progress, blocked, review, and completion state) in the provider source before advancing. Remote provider state remains authoritative; local snapshots are read-only temporary context and never a writable shadow or fallback state. Do not use handoff text as durable state.

Claim acquisition is one linearized compare-and-set in the selected claim authority, never a read-then-write marker. It records a caller-generated claim ID, identities, work key, authority time, bounded expiry, revision, and random token only when the resource is free or expired. Retrying one claim ID is idempotent; every new ownership epoch uses a new ID/token and higher revision to prevent ABA. Heartbeat, guarded mutation, and release require the exact current claim ID/token/revision. A stale worker cannot write through the helper or clear its successor.

Provider-native fencing may transact eligibility and provider writes with the claim. The same-host authority cannot transact with GitHub or Backlog.md storage: it guarantees exclusive scheduling and guarded CLI execution only among cooperating agents using this helper on one host. Therefore refresh provider eligibility/version before acquisition, immediately after acquisition, and before each guarded mutation; preserve unrelated provider fields and treat any provider-side conflict/change as a stop/reconciliation condition. Do not describe local-host claims as cross-host exclusion or provider-side CAS.

Use a bounded authority lease duration. The holder heartbeats before half elapses and around long work; `exec` renews internally while its one CLI child owns the local fence. Revalidate dependencies before delegation, integration, and checkpoints. If a dependency reopens or a provider version changes, stop, checkpoint only still-authorized resumable state when safe, and release. Resolve ambiguous claim operations by exact claim ID and ambiguous provider writes by refreshing provider state; never start or transfer work while ownership is uncertain.

Persist the coherent task/specification/refinement-complete/review/archive checkpoint through the provider under a valid claim before release. If checkpointing or release fails, do not advance scheduling; retain receipts and let the claim remain until repaired or expired. A normal handoff releases while preserving `in-progress`; an unexpected stop is recovered by expiry and a fresh claim ID. If the selected authority lacks atomic claim transitions, authority time, idempotent recovery, or enforcement on every cooperating-agent write path, return a claim-capability error before work.

Archive is a provider operation, not a scheduling decision. It is allowed only when the caller authorizes it and the provider section defines the operation. Closing a GitHub issue, archiving a Linear item, archiving a Backlog.md task, or moving an existing loose-Markdown source to its established archive location must be recorded with the provider receipt.

## Provider extension rule

A future provider adds one provider section that implements source detection, complete discovery, dependency/status/order/claim mapping, atomic fenced claim/heartbeat/release, durable read/write/progress, review-boundary resolution, and archive. It may retain opaque fields in `providerData`, but it must not change these normalized values, dependency-first selection, claim semantics, default one-item review boundary, or command call sites. If a capability is unavailable, return a structured capability error rather than changing the contract.
