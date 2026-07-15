# Generic Work Coordination Contract

This contract defines a backend-neutral boundary for agents and human-operated tools that coordinate work. It does not define a provider, transport, database, filesystem layout, command, authorization mechanism, or source-specific status mapping.

## Design rule

The caller supplies capabilities and opaque values. The workflow must not infer a backend from an ID, path, title, environment variable, repository marker, or command result. If the caller cannot provide a required capability, return `capability` with the missing operation and stop that path.

## Normalized values

### `Source`

```text
Source {
  id: opaque stable source identity
  locator: opaque caller-resolved locator
  name: human-readable display name
  metadata: opaque caller-owned values
}
```

A source is an identity and capability context, not an authorization grant. Resolution is read-only until the caller passes explicit authority to a mutation.

### `WorkRef`

```text
WorkRef {
  sourceID: exact Source.id
  itemID: opaque stable source-local item identity
}
```

Every item, dependency, explicit selection, and review member is source-qualified. Provider-local IDs are never assumed globally unique.

### `WorkItem`

```text
WorkItem {
  source: Source
  ref: WorkRef
  title: string
  body: string or opaque caller-owned content
  dependencies: ordered WorkRef[]
  state: opaque caller state plus isTerminal/isBlocked booleans
  priority: opaque or null
  order: caller-defined stable ordering value or null
  progress: none | in-progress | complete
  review: none | pending | in-progress | complete
  claim: WorkClaim or null
  metadata: opaque caller-owned values
}
```

`state` remains caller-owned. The booleans are the only scheduling interpretation required by this contract: a dependency is implementation-ready only when the caller reports it terminal, and blocked work is never selected.

### `WorkClaim`

```text
WorkClaim {
  target: WorkRef or Source.id
  resource: exact opaque key used by the claim authority
  workKey: exact caller-defined operation key
  mode: opaque workflow mode
  claimID: unique ownership-epoch ID
  agentID: caller-visible agent identity
  ownerID: unique worker-attempt identity
  sessionID: invocation/session identity
  authority: opaque claim-authority identity
  guarantee: fenced | local-coordination
  guaranteeScope: exact host/process/mutation scope the authority guarantees
  providerMutationFenced: boolean, false unless the provider write supplies fencing evidence
  revision: exact claim-authority compare-and-set revision
  token: opaque ownership token
  acquiredAt: authority timestamp
  acquireTTL: bounded lease duration accepted at acquisition
  heartbeatAt: authority timestamp
  expiresAt: authority timestamp
}
```

Absence of a claim is represented by `WorkItem.claim: null` plus a structured `capability` or guarantee outcome, never by a synthetic `WorkClaim`. A new attempt may replace an expired claim with a fresh claim ID and token, but may not adopt or renew an unexpired claim because its agent or session identity matches. An active claim is one bounded ownership epoch for one exact authority resource. `fenced` means the named mutation executes inside the authority boundary described in `guaranteeScope`; it never implies a wider provider or cross-host fence. `local-coordination` means only cooperating callers under the stated local scope are excluded.

`WorkClaim` is normalized adapter state, not the raw Worklease wire object. A Worklease adapter maps `claimId` to `claimID`, `acquiredAt` unchanged, and `acquireTtl` to `acquireTTL`; it records `guaranteeScope` and `providerMutationFenced` from caller/provider evidence because Worklease does not emit those fields. The raw Worklease `fenced` value advertises eligibility for a same-host guarded local operation; normalize the workflow guarantee to `local-coordination` when the durable provider mutation occurs outside that guard. Keep provider source versions in provider metadata or a separate provider receipt; never overload the claim-authority revision.

The token is a bearer credential. Pass it only to claim mutations and guarded operations. Never include it in read-only status, diagnostics, provider checkpoints, logs, or handoffs.

### `SchedulingScope`

```text
SchedulingScope {
  sources: ordered Source[]
  items: ordered WorkItem[]
  sourceOnly: boolean
  explicitItemRefs: ordered WorkRef[]
  implementationItem: WorkItem or null
  reviewBoundary: ReviewBoundary or null
}
```

Explicit source and selector order is preserved. Dependency reads may include items outside an explicit selection, but selection and mutation remain inside the authorized scope. Source-only scope enumerates the complete collection; it is not a first-item shortcut and does not imply source-wide review.

### `ReviewBoundary`

```text
ReviewBoundary {
  id: opaque caller-defined ID or null
  label: string
  itemRefs: ordered WorkRef[]
  explicit: boolean
}
```

The default review boundary is exactly one implementation item. A larger boundary requires an explicit caller request and a caller capability that can resolve and durably persist it. Never infer a milestone, parent, group, or source-wide review.

## Interfaces

### Caller and adapter capabilities

The caller exposes equivalent provider and claim-authority operations and supplies each claim authority with an exact opaque resource from caller or adapter context. Names are illustrative; another API is valid when the observable guarantees remain the same.

1. `resolveSources(arguments, context)` returns ordered `Source[]` and diagnostics without mutating.
2. `discover(source, selector?)` returns every matching `WorkItem`, plus dependency items needed for graph validation.
3. `readItem(ref)` refreshes one durable item before claim, write, review, or archive.
4. `readClaim(resource, authority)` returns the current claim metadata without exposing its bearer token.
5. `claim(resource, request, authority)` atomically claims an absent or expired resource and returns the normalized `WorkClaim` plus the authority receipt.
6. `heartbeat(resource, claimID, token, revision, operationID, ttl, authority)` conditionally extends only the matching unexpired claim and returns its new revision.
7. `releaseClaim(resource, claimID, token, revision, operationID, reason, authority)` conditionally releases only the matching claim. Checkpoint-before-release is a caller-enforced precondition.
8. `writeState(ref, patch, authority, claim?)` writes caller-owned durable state and returns a provider receipt.
9. `recordProgress(ref, marker, authority, claim?)` writes caller-owned durable provider checkpoint.
10. `resolveReviewBoundary(scope, requestedBoundary, authority)` resolves an explicitly requested provider boundary and its exact members.
11. `archive(source, target, authority, claim?)` performs an explicitly authorized caller-owned archive operation.

The caller passes authority and scope unchanged to mutations. Reads and resolution cannot expand either. The caller or provider adapter must supply opaque claim resources and merge claim-authority reads into scheduling state before selection; the generic workflow never infers a resource from provider values. A provider write receipt must identify the durable source/version where the caller can discover the result; a claim or guarded-operation receipt alone does not satisfy that requirement.

### Generic workflow operations

The generic workflow, not a provider adapter, builds and validates the dependency graph, implements `selectNext(scope, mode)` and `selectWave(scope, mode)`, applies source/selector ordering and tie-breakers, and returns structured no-work outcomes. It supplies the default one-item review boundary and calls `resolveReviewBoundary` only for an explicit larger request. Provider adapters supply normalized fields and operations; they do not reimplement scheduling.

## Resolution and selection

- Resolve every explicit source and selector in supplied order. Do not reorder by priority, source type, or whichever capability answers first.
- If any explicit source fails, report that failure; do not silently derive another source.
- When no source is explicit, the caller may derive one only under its own unambiguous repository/context rules. This contract does not define those rules.
- Resolve item selectors and dependency references to exact `WorkRef` values before graph construction. A source-local ID without its source identity is ambiguous in a multi-source scope.
- Require one exact opaque claim resource supplied by the caller or provider adapter for each target and operation scope. Its derivation remains outside this contract, and every contender must receive the same byte-for-byte value.
- Build the complete dependency graph before selecting work.
- Missing dependencies and directed cycles block every affected item.
- A dependency is not complete because it is assigned, claimed, in progress, reviewed, or locally marked; the caller must report it terminal.
- Exclude completed/terminal, blocked, dependency-ineligible, and actively claimed items.
- An unclaimed in-progress item may be resumed when the caller says it is eligible.
- If no work is selectable, report why: `complete`, `blocked`, `active-claims`, or a structured combination. Never select a later dependent merely to avoid an empty result.
- Within the ready wave, preserve explicit selector/source order, then apply only the caller's documented priority/order/stable-`WorkRef` tie-breakers.

## Claim, lease, and mutation invariants

- Acquire with one compare-and-set operation, never a read-then-write marker.
- Treat the caller-derived resource as opaque after derivation. Never derive it from transient session, agent, worktree, checkout, or process identity.
- Generate globally unique claim, session, worker-attempt, and operation IDs.
- Retry the same operation ID only to recover the exact same request's lost response; changed inputs, including TTL or release reason, conflict.
- Every new ownership epoch uses a new claim ID and token. Retain the revision returned by the authority.
- Heartbeat requires the exact current claim ID, token, revision, an operation ID for that renewal request, and a bounded renewal TTL. Release requires the exact current claim ID, token, revision, an operation ID for that release request, and a non-blank reason. An idempotent retry reuses the original operation ID and exact inputs.
- Replace the held revision with the revision returned by every successful heartbeat or guarded operation.
- Heartbeat before half the lease elapses and around long work.
- Re-read eligibility, the exact claim, and provider state immediately before durable mutation. After the mutation, re-read the claim and source/version when the caller can do so.
- If ownership, guarantee scope, or the provider write result is uncertain, stop further work and return an ambiguity/conflict diagnostic. Do not release a successor's claim.
- Persist and verify a coherent task/progress/review/archive checkpoint through the provider before invoking release. A claim receipt, guarded-operation receipt, command exit status, release reason, or handoff text alone is not durable provider state.
- Checkpoint-before-release is caller policy; Worklease validates ownership and a non-blank audit reason but does not inspect a provider receipt. A failed or unverified provider checkpoint means the caller must not invoke release.

## Authority guarantees

The caller must state the exact scope and guarantee it can prove:

- `fenced`: the named mutation executes within the claim authority's compare-and-set/fencing boundary. For Worklease, this can describe the matching same-host guarded `exec` or `replace-file` operation, not an arbitrary provider mutation or cross-host exclusion.
- `local-coordination`: cooperating callers on the stated local scope are excluded, but the provider mutation is not fenced by the claim. The caller must pre-check and post-check the claim and provider state around direct mutation.
- `none`: a structured capability outcome indicating no usable ownership guarantee; it is never a `WorkClaim`. Do not delegate or mutate as claimed work.

Set `providerMutationFenced` to `false` by default. Set it to `true` only when the durable provider mutation itself shares the provider compare-and-set/fencing boundary and returns evidence. Pre/post reads under a local claim can detect some races but do not fence the mutation.

Never promote a lock, lease, assignment, status, comment, branch, worktree, local cache, or local command receipt into a stronger guarantee. A provider CLI or remote API invoked from a locally guarded process is still not provider-fenced unless the provider mutation itself shares the CAS/fence and returns evidence of it.

## Durable authority and archive

The caller's backing source remains authoritative for item content, dependencies, status, progress, review, and completion. Any local claim store or cache is coordination/context only and is never a writable shadow source. A local guarded-operation receipt proves only that local operation's outcome and scope; it does not replace a provider receipt or verified provider state. Review and archive are caller operations, not scheduling shortcuts: they require explicit authority, matching claim where applicable, and a durable provider receipt. Deleting a source is not an archive operation unless the caller's own contract explicitly defines deletion as archive.

## Structured result vocabulary

A caller should make these outcomes machine-readable while preserving human-readable diagnostics:

- `complete`: all scoped work is terminal;
- `blocked`: unfinished work has missing/cyclic/blocked/unfinished prerequisites;
- `active-claims`: otherwise-ready work is held by unexpired claims;
- `capability`: a required caller operation or authority is unavailable;
- `ineligible`: the target fails a current readiness check;
- `conflict`: claim, revision, selector, or source version changed;
- `ambiguous`: the caller cannot establish what durable mutation occurred.

Unknown backend values belong in opaque metadata. They must not alter these coordination invariants.
