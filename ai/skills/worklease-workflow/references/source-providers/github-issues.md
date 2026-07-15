# GitHub Issues

## Source and item mapping

Resolve an explicit repository locator or one caller-configured repository. The caller supplies the authorized GitHub integration; this reference does not choose a CLI, SDK, MCP server, or credential source.

- `Source.id`: canonical repository identity
- `WorkRef.itemID`: issue number or stable node ID, always qualified by `Source.id`
- dependencies: provider-native sub-issue/blocked relationships or one caller-documented relation; unsupported dependency semantics remain empty/`capability`, not inferred from prose
- terminal/blocked state: explicit mapping of issue state and caller-owned blockers
- order: caller-documented priority/labels/order after dependency and explicit-source ordering

Discovery must paginate the complete selected collection. A bare issue number is ambiguous without a resolved repository.

## Worklease resource policy

Use the bundled GitHub key policy after repository and issue resolution:

```python
from worklease.adapters import key

resource_key = key("github", repository, issue_number)
```

This creates an item-scoped local key. A locally guarded GitHub command is not a provider-fenced issue mutation; other hosts and direct writers remain possible. Default to `providerMutationFenced: false` and normalize the mutation guarantee as `local-coordination` unless the selected GitHub operation atomically enforces a supplied provider version and returns evidence.

## Authoritative operations

Refresh the issue immediately before mutation and preserve fields not named by the requested patch. The durable receipt contains the repository-qualified issue identity, resulting state, and provider version or updated marker that can be re-read. A local command receipt alone is insufficient.

Review boundaries larger than one issue require an explicit caller selector with exact members. Closing or otherwise archiving an issue is allowed only when the caller defines that provider operation as the requested archive behavior; never infer source-wide closure from source-only discovery.
