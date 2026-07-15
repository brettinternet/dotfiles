# Source Provider Contract

This contract defines the provider-specific delta required by the normative [`contract.md`](contract.md). It does not replace or restate that contract.

## Adapter declaration

A source workflow adapter declares equivalent capabilities. Names are illustrative; the caller may use a CLI, SDK, MCP tool, database transaction, or local file operation when its observable behavior matches.

```text
SourceProvider {
  kind: opaque caller-selected provider kind
  resolve(arguments, context) -> ordered Source[] | diagnostic
  discover(source, selector?) -> ordered WorkItem[] plus dependency items
  readItem(ref: WorkRef) -> current WorkItem plus provider version
  resourcePolicy(ref: WorkRef, workKey) -> exact resource plus local capability
  writeState(ref, patch, authority, expectedVersion?) -> ProviderReceipt
  recordProgress(ref, checkpoint, authority, expectedVersion?) -> ProviderReceipt
  resolveReviewBoundary(scope, explicitSelector, authority) -> ReviewBoundary
  archive(target, authority, expectedVersion?) -> ProviderReceipt
}
```

Resolution and discovery are read-only. Mutation operations exist only when the caller supplies explicit authority. Unsupported operations return `capability` with the missing operation and provider kind.

## Normalized mapping

- `Source.id` is stable within caller context and qualifies every item reference.
- `WorkRef` is `{sourceID, itemID}`; provider-local IDs are never treated as globally unique.
- `WorkItem.ref` equals the exact source-qualified reference.
- `WorkItem.dependencies` contains complete source-qualified prerequisites, including unresolved references as blocking diagnostics.
- `state.isTerminal` and `state.isBlocked` are explicit adapter interpretations; raw provider status remains in metadata.
- Provider priority/order values are normalized without overriding dependency edges or explicit source/selector order.
- Provider versions, updated timestamps, ETags, or transaction revisions remain provider metadata or `ProviderReceipt` fields. They never replace the Worklease claim revision.

A provider reference must define how each value is read and how duplicate or ambiguous selectors fail. It must not define a competing scheduling algorithm.

## Resource policy

The caller supplies provider, source, and item identity before resource derivation. Prefer the bundled `worklease.adapters` key policy when its identity and claim scope fit:

```python
from worklease.adapters import key

resource_key = key(provider_kind, source_locator, item_id)
```

The returned `resource` is passed unchanged to Worklease. `capability` and `scope` describe local coordination policy, not provider discovery or provider-side fencing. Every contender for the same logical claim scope must receive the same exact resource.

Resource policies are separate from source-provider adapters: they only select the local resource identity and guarantee declaration. A source-provider adapter owns reads, writes, receipts, review boundaries, and archive behavior; the generic workflow owns scheduling and claim lifecycle.

External policies use the version-1 `worklease.resource_policies` entry-point contract. A descriptor declares origin, key-policy version, claim scope, capability, generic execution guarantee, and provider-fencing support. Installable wheels and editable installs can discover these registrations lazily; standalone frozen executables expose built-ins only.

A custom resource policy must document canonicalization, claim granularity, collision avoidance across sources, and worktree/checkout stability. Session, agent, process, or temporary-path identity must not enter the resource.

## Provider receipts

```text
ProviderReceipt {
  sourceID: exact Source.id
  ref: WorkRef or null for source-wide writes
  operation: caller-authorized mutation
  providerVersion: opaque post-write version or null
  durableLocation: provider-native locator
  observedState: fields proving the requested checkpoint
  conditionalWrite: boolean
  fencingEvidence: opaque provider evidence or null
}
```

A command exit status or Worklease receipt alone is not a provider receipt. If the provider mutation response lacks the resulting version/state, re-read the authoritative source and retain that result. An ambiguous write remains `ambiguous`; do not infer success from a local operation receipt.

## Guarantee declaration

Record two separate facts:

1. Worklease claim `guarantee` and `guaranteeScope`, describing the guarded local operation or local coordination boundary.
2. `providerMutationFenced`, describing whether the durable provider mutation itself shared a provider compare-and-set/fencing boundary.

`providerMutationFenced` defaults to `false`. Set it to `true` only when `conditionalWrite` is true and `fencingEvidence` proves the provider rejected stale writers as part of the same durable mutation. Pre/post reads detect some conflicts but do not make the mutation provider-fenced.

## Generic workflow handoff

After producing normalized sources, items, resource policy, and declared capabilities, hand them to `worklease-workflow`. The provider adapter responds to capability calls when invoked; it does not expose a scheduler, work loop, `selectNext`, `selectWave`, claim lifecycle, or release policy. The normative contract alone decides graph construction, operation ordering, claim/revalidation timing, checkpoint-before-release, and structured outcomes.
