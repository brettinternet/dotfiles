# Example: Provider Conditional Write

Use this shape only when the provider mutation itself atomically checks a provider version or fencing token and rejects stale writers.

## Required provider behavior

```text
before = provider.readItem(ref)
receipt = provider.writeState(
  ref,
  requestedPatch,
  expectedVersion = before.version
)
```

The write must satisfy all of these conditions:

1. `expectedVersion` participates in the same durable provider transaction as the requested patch.
2. A stale value causes a conflict and applies no patch.
3. Success returns the new provider version and resulting state, or those values can be read unambiguously.
4. The receipt identifies the authoritative provider location and exact `WorkRef`.
5. The provider operation is authorized independently of the Worklease claim.

A before/after read without atomic conditional enforcement does not satisfy this shape.

## Guarantee composition

Worklease and provider guarantees remain separate:

```text
Worklease claim:
  guarantee: local-coordination or fenced for its named local operation
  guaranteeScope: exact local host/operation boundary

Provider receipt:
  conditionalWrite: true
  providerVersion: new durable version
  fencingEvidence: provider-native conditional-write receipt

Normalized workflow:
  providerMutationFenced: true
```

`providerMutationFenced: true` applies only to the provider operation evidenced by that receipt. It does not upgrade the Worklease store to cross-host coordination and does not carry to later writes that omit the provider condition.

## Failure path

On provider conflict:

1. retain the current Worklease claim if ownership is still valid;
2. refresh the provider item and dependencies;
3. return `conflict` to the generic workflow;
4. retry only as a new caller-authorized provider operation with a fresh expected version; and
5. checkpoint and release only after one verified successful mutation.

Do not retry a Worklease operation ID with changed provider inputs. Worklease idempotency recovers one exact local request; it is not a substitute for provider idempotency or conditional mutation.
