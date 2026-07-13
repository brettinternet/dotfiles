# Local provider sections

Load only the heading for the provider selected by `references/contract.md`.

## Loose Markdown

Loose Markdown is an existing repository Markdown backlog whose item headings, checkboxes, labels, IDs, dependencies, and progress markers already provide the source convention. It is not a license to invent a second backlog format.

### Discovery

- For an explicit path, validate that the file exists and structurally contains backlog items (for example, item headings or an item checklist). A random Markdown file that merely mentions an ID is not a source.
- For repository-derived detection, inspect only established conventional backlog paths and accept the source only when the contract's candidate set has exactly one member. If two Markdown files are plausible, report ambiguity.
- Discover the complete file collection for source-only scope. Parse each item into `ItemState`, retaining the heading/checklist order as `ordinal` and preserving the source text and existing stable ID in `providerData`.
- Map status, refinement/review checkpoints, priority, and dependency references from the existing vocabulary. Derive the source-wide local claim key with `backlog-claim key --provider markdown --source <path> --item <any-selected-id>` and merge `backlog-claim status` into each normalized `ItemState`; the helper intentionally returns the same source resource for every item. An absent dependency target is unresolved, not complete. If the convention has no explicit ID, use its established file/heading identity and keep it stable across edits; do not manufacture a new format.
- An explicit `review-group:<provider-native-selector>` is supported only when this source convention supplies a stable group identity, deterministic member enumeration, and a writable group-marker location. Resolve the selector through that convention, return the complete exact ordered member IDs in `ReviewGroup`, and reject an invalid or unsupported selector with a capability/invalid-selector diagnostic. Never infer membership from headings, labels, adjacency, or other incidental Markdown.

### Durable mutation and progress

- Source resolution and discovery are read-only. Outside `mode:spec-only`, normal refinement/implementation/review/archive requires the same-host fenced `source-claim`; direct edits are forbidden. In `mode:spec-only`, the command's single-mutator rule permits the existing direct-edit convention because that mode intentionally does not claim.
- Under a claim, build the complete next source content in a temporary candidate, compute the authoritative source's current SHA-256, then call `backlog-claim replace-file` with the source resource, current claim ID/token/revision, fresh operation ID, target path, expected SHA-256, and candidate path. Only its successful receipt is a source write. A file-version conflict, stale claim, or ambiguous receipt requires a fresh source read and ownership check; never retry with a weakened expected hash or use the ordinary edit tool.
- `writeState` and `recordProgress` preserve surrounding prose, heading levels, checkbox syntax, labels, ordering, unknown fields, and the existing item convention in the candidate. A normal refinement persists a discoverable `refinement: complete` checkpoint with the specification receipt/version; `mode:spec-only` does not. A handoff or claim release is not durable progress.
- `reviewBoundary` may persist an explicit group marker only at the established writable location and through the same claimed source replacement. Require the marker write's receipt plus exact ordered member IDs before reporting success; otherwise return a capability error.
- Do not create a new backlog/spec file merely to hold state. If an item has no writable convention, return a capability error rather than silently creating one.
- Declare fenced `source-claim` through `backlog-claim`; never declare `item-claim` for multiple items in one Markdown file. Its resource lock, claim CAS, expected-hash CAS, atomic replacement, and release share the source fence. This supports same-host workers only. An unavailable helper, direct claimed edit, second sidecar, or cross-host worker without a shared CAS service is capability `none`.

### Archive

Archive only through an established repository convention: for example, moving an existing source or completed section to its documented archive location. Preserve the original content and record the resulting path/marker as the durable receipt. Never delete an item or source to simulate archive, and never archive merely because it was enumerated by a source-only schedule.

## Backlog.md

Backlog.md is a distinct local provider. The project/task model and its durable state belong to Backlog.md, not to ad hoc Markdown parsing.

### Discovery

- Resolve an explicit project path or Backlog.md locator through the supported `backlog` CLI/MCP discovery operation. Repository-derived detection requires an unambiguous Backlog.md project marker and must not be guessed from arbitrary `.md` files.
- Use the supported `backlog` CLI/MCP task/project listing operations to enumerate the entire project for source-only scope. Do not stop after the first open task and do not read project files as a substitute for the provider operation.
- Map provider task IDs, title/body, status, priority, order, dependencies, and refinement/review checkpoints into `ItemState`. Derive an item resource with `backlog-claim key --provider backlog-md --source <project> --item <task-id>` and merge `backlog-claim status` as the current claim; Backlog.md assignee and workflow status are visibility/progress, not claims.
- Use the provider's status vocabulary to determine terminal dependencies and review-pending work. Preserve provider ordering and opaque fields in `providerData`; preserve the local claim receipt separately in `WorkClaim`.
- For an explicit `review-group:<provider-native-selector>`, pass the provider-native selector unchanged to the supported CLI/MCP group operation. Milestone/parent groups are valid only when that operation resolves the complete exact ordered member IDs and returns a stable group identity; invalid selectors or unavailable group resolution are capability/invalid-selector diagnostics, not inferred membership.

### Durable mutation and progress

- All Backlog.md reads use the supported `backlog` CLI/MCP. Outside `mode:spec-only`, claimed mutations use the CLI only and each status/task/dependency/progress/review/completion/archive write runs as exactly one `backlog-claim exec ... -- backlog ...` operation with the current item claim. Direct task-file edits and unguarded CLI/MCP writes are forbidden.
- After acquisition, project visible ownership with a guarded `backlog task edit <task-id> -a @<assignee>` call before work. Resolve `<assignee>` from `BACKLOG_CLAIM_ASSIGNEE` when set, otherwise use the stable active `agentID`; retain the exact value in the claim report. The assignment is not the lease, is never consulted for eligibility, and may remain as historical visibility after release.
- Pass the caller's exact item/review scope to each guarded CLI call. Retain both the helper receipt/new claim revision and Backlog.md result. A failed/ambiguous command leaves the item incomplete and the claim unreleased until reconciled or expired.
- Persist group markers and `recordProgress` through guarded provider CLI mutations. Normal refinement stores a discoverable `refinement: complete` checkpoint with its specification receipt/version; `mode:spec-only` leaves progress unchanged.
- Declare same-host `item-claim` through `backlog-claim` when the supported `backlog` CLI is installed. Acquisition, heartbeat, guarded CLI writes, recovery, and release use one item resource. The Backlog.md assignment is only a provider-visible projection. MCP-only mutation, unavailable CLI/helper, cross-host workers without shared CAS, or any bypass around `backlog-claim exec` is capability `none`.

### Archive

Archive or complete a Backlog.md task only through the supported provider operation. Under a normal-mode claim, run the CLI archive/close command through `backlog-claim exec`; `mode:spec-only` has no archive authority. Do not remove or rename project files directly, and do not infer that all tasks in a source-only collection should be archived.
