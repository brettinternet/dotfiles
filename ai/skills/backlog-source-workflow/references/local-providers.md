# Local provider sections

Load only the heading for the provider selected by `references/contract.md`.

## Loose Markdown

Loose Markdown is an existing repository Markdown backlog whose item headings, checkboxes, labels, IDs, dependencies, and progress markers already provide the source convention. It is not a license to invent a second backlog format.

### Discovery

- For an explicit path, validate that the file exists and structurally contains backlog items (for example, item headings or an item checklist). A random Markdown file that merely mentions an ID is not a source.
- For repository-derived detection, inspect only established conventional backlog paths and accept the source only when the contract's candidate set has exactly one member. If two Markdown files are plausible, report ambiguity.
- Discover the complete file collection for source-only scope. Parse each item into `ItemState`, retaining the heading/checklist order as `ordinal` and preserving the source text and existing stable ID in `providerData`.
- Map status, refinement/review checkpoints, priority, dependency references, and current item/source claim from the existing vocabulary. An absent dependency target is unresolved, not complete. If the convention has no explicit ID, use its established file/heading identity and keep it stable across edits; do not manufacture a new format.
- An explicit `review-group:<provider-native-selector>` is supported only when this source convention supplies a stable group identity, deterministic member enumeration, and a writable group-marker location. Resolve the selector through that convention, return the complete exact ordered member IDs in `ReviewGroup`, and reject an invalid or unsupported selector with a capability/invalid-selector diagnostic. Never infer membership from headings, labels, adjacency, or other incidental Markdown.

### Durable mutation and progress

- Direct edits are permitted only for the selected existing source and only when no operation-specific local tool exists. Preserve surrounding prose, heading levels, checkbox syntax, labels, ordering, and unknown provider fields.
- `writeState` and `recordProgress` edit the existing item in its established style. A normal refinement persists a discoverable `refinement: complete` checkpoint with the specification receipt/version; `mode:spec-only` does not. Write the actual status/checklist/progress marker before reporting the checkpoint; a handoff or claim release is not durable progress.
- Source resolution and discovery are read-only. Use the caller's authority for every edit and refuse writes outside the selected source/item or explicitly authorized review group.
- `reviewBoundary` may persist an explicit group marker only at that established writable location. Require the marker write's durable commit state/receipt together with the exact ordered member IDs before reporting success; otherwise return a capability error. Never downgrade to an item-local marker or create a local shadow marker.
- Do not create a new backlog/spec file merely to hold state. If an item has no writable convention, return a capability error rather than silently creating one.
- Declare `item-claim` only when the source can atomically update an item lease; otherwise a source-wide compare-and-set/lock over this authoritative file may declare fenced `source-claim`. Both must use provider/file-domain time, unique claim ID/revision, idempotent recovery reads, and the same atomic domain to fence specification/progress/status/completion/release writes. An ordinary read/edit/commit or sidecar is `none` and returns a capability error before work.

### Archive

Archive only through an established repository convention: for example, moving an existing source or completed section to its documented archive location. Preserve the original content and record the resulting path/marker as the durable receipt. Never delete an item or source to simulate archive, and never archive merely because it was enumerated by a source-only schedule.

## Backlog.md

Backlog.md is a distinct local provider. The project/task model and its durable state belong to Backlog.md, not to ad hoc Markdown parsing.

### Discovery

- Resolve an explicit project path or Backlog.md locator through the supported `backlog` CLI/MCP discovery operation. Repository-derived detection requires an unambiguous Backlog.md project marker and must not be guessed from arbitrary `.md` files.
- Use the supported `backlog` CLI/MCP task/project listing operations to enumerate the entire project for source-only scope. Do not stop after the first open task and do not read project files as a substitute for the provider operation.
- Map provider task IDs, title/body, status, priority, order, dependencies, refinement/review checkpoints, and current item/source claim into `ItemState`. Refresh dependency targets with the same provider operation when the listing is incomplete.
- Use the provider's status vocabulary to determine terminal dependencies and review-pending work. Preserve ordering, provider time, concurrency/version fields, and opaque fields in `providerData`.
- For an explicit `review-group:<provider-native-selector>`, pass the provider-native selector unchanged to the supported CLI/MCP group operation. Milestone/parent groups are valid only when that operation resolves the complete exact ordered member IDs and returns a stable group identity; invalid selectors or unavailable group resolution are capability/invalid-selector diagnostics, not inferred membership.

### Durable mutation and progress

- All Backlog.md mutations use the supported `backlog` CLI or MCP operation: status/task edits, dependency changes, progress markers, review state, and completion. Never directly edit Backlog.md project/task files when a CLI/MCP operation exists.
- Pass the caller's authority and exact item/review scope to each CLI/MCP call. A successful provider response is the durable receipt; a failed call leaves the item incomplete and must be reported.
- Persist an explicit Backlog.md group marker only through the supported CLI/MCP operation, and require its durable marker commit state/receipt plus the exact ordered member IDs before reporting success. If the installed provider cannot persist group state, return a capability error; never mark only the implementation item, edit project/task files directly, or create an ad hoc/local shadow marker.
- `recordProgress` uses provider task fields/comments/markers, not a local note. Normal refinement stores a discoverable `refinement: complete` checkpoint with its specification receipt/version; `mode:spec-only` leaves progress unchanged.
- Declare `item-claim` or fenced `source-claim` only when the supported CLI/MCP transaction conditionally revalidates eligibility and provides provider time, unique claim/revision, idempotent recovery, renew/release, and fencing on actual work mutations. Partial or unfenced support is `none` and returns a claim-capability error before work.

### Archive

Archive or complete a Backlog.md task only through the supported `backlog` CLI/MCP archive/close operation. Use any project-level archive operation the provider exposes for a source archive. Do not remove or rename project files directly, and do not infer that all tasks in a source-only collection should be archived.
