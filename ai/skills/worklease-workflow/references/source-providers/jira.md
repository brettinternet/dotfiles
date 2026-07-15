# Jira

## Source and item mapping

Resolve an explicit Jira site plus project/filter/board locator or one caller-configured source. Project keys and issue keys are not globally unique across Jira sites, so `Source.id` must include the site identity.

- `Source.id`: canonical site plus selected collection identity
- `WorkRef.itemID`: stable issue ID or issue key qualified by `Source.id`
- dependencies: caller-selected Jira link types such as blocking relations, converted to source-qualified references
- terminal/blocked state: explicit mapping of the project's configurable workflow statuses, resolution, and blockers
- order: provider rank/priority/order after dependency and explicit-source ordering

Discovery must follow provider pagination and include dependency items needed for readiness. Do not assume that status names or link-type names are consistent across Jira projects.

## Worklease resource policy

Jira uses the explicit built-in `generic` coordination policy because no provider-specific resource policy is bundled:

```python
from worklease.adapters import key

resource_key = key("generic", f"jira:{site}:{source_locator}", issue_id)
```

Include the Jira site and collection identity in the source so distinct Jira systems cannot collide under the shared generic policy. The result is item-scoped `local-coordination`; it does not fence Jira mutations. Default `providerMutationFenced` to `false`; set it to `true` only when the caller's Jira operation supplies and atomically enforces a provider version/conditional predicate and returns evidence. A successful local request, assignee, transition, or updated timestamp alone is not fencing.

## Authoritative operations

The caller supplies authorized Jira reads, transitions, edits, comments, and archive-equivalent operations. Refresh the issue and relevant links immediately before mutation. Preserve fields outside the requested patch. Retain the resulting issue identity, workflow state, and provider version or re-read them as the durable checkpoint.

A larger review boundary requires an explicit filter/epic/parent/other provider selector with exact members. Jira installations vary in completion and archive capabilities; use the caller-defined transition or archive operation when supported, otherwise return `capability`. Never delete an issue or create a local mirror as an archive substitute.
