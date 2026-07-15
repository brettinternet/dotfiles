# Linear

## Source and item mapping

Resolve an explicit Linear workspace/team/project locator or one caller-configured source. The caller supplies the authorized Linear integration and credentials.

- `Source.id`: stable workspace plus team/project identity
- `WorkRef.itemID`: stable issue ID, qualified by `Source.id`
- dependencies: provider-native blocking relations converted to source-qualified references
- terminal/blocked state: explicit mapping of the source's workflow states and blockers
- order: provider priority/order after dependency and explicit-source ordering

Discovery must enumerate the complete selected project/team collection and dependency closure. An issue identifier that can resolve in multiple teams or workspaces is ambiguous.

## Worklease resource policy

The bundled Linear key policy is coordination-only:

```python
from worklease.adapters import key

resource_key = key("linear", source_locator, issue_id)
```

It derives a deterministic item resource but cannot guard the remote mutation. Keep the Worklease guarantee `local-coordination` and `providerMutationFenced: false` unless the caller supplies a Linear operation that atomically rejects stale versions and returns fencing evidence. Assignment, status, or a comment is visibility, not a claim.

## Authoritative operations

Use caller-authorized Linear reads and mutations. Refresh current issue state and provider version/updated marker before writing, preserve unrelated fields, and retain or re-read the resulting issue as the durable receipt. Pre/post reads can detect some races but do not make the mutation provider-fenced.

Resolve larger review boundaries only from an explicit provider-native project, initiative, parent, or other selector whose exact members can be returned and persisted. Archive/complete behavior must preserve the provider's distinction when one exists; unsupported archive operations return `capability` rather than deleting or shadowing an issue.
