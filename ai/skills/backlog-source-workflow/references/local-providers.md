# Local Providers

Load only the selected provider heading. The shared contract owns ordering, scope, dependencies, review boundaries, authority, claim semantics, and durable-state rules.

## Loose Markdown

Treat an existing repository Markdown backlog as one source using its established headings, checkboxes, labels, IDs, dependencies, and progress vocabulary. Do not invent a second format.

**Discovery:** Validate an explicit path structurally contains backlog items. Repository detection inspects only conventional backlog paths and requires one candidate. Discover the complete file for source-only scope, retain item order as `ordinal`, and preserve source text/stable identity in `providerData`. Map state/checkpoints/dependencies from the existing vocabulary; unresolved dependencies stay unresolved. If no explicit IDs exist, keep the established file/heading identity stable. Derive and merge the source-wide helper claim status. Support explicit review groups only when the source convention has a stable selector, exact deterministic members, and writable group-marker location.

**Mutation:** Normal mutation requires the fenced source claim described in [`claims.md`](claims.md); direct edits are forbidden. Build complete candidate content, hash the current authoritative file, and use `backlog-claim replace-file`. On conflict/ambiguity, reread source and ownership rather than weakening the expected hash. Preserve prose, heading levels, syntax, ordering, and unknown fields. Normal refinement writes its discoverable checkpoint in the same replacement. `mode:spec-only` uses the caller's single-mutator direct-edit convention and changes specification content only. An unavailable helper is capability `none` outside that mode. Never create a sidecar or new backlog merely to hold workflow state.

**Archive:** Move existing content only through an established repository archive convention and retain the resulting path/marker. Never delete to simulate archive.

## Backlog.md

Treat Backlog.md as a provider-owned project/task model, not ad hoc Markdown.

**Discovery:** Resolve and enumerate through supported `backlog` CLI/MCP operations; never parse or edit task files directly. When the source is inside a Git worktree, map its repository-relative location to the unambiguous primary/control checkout and use that canonical checkout for every provider read, refresh, write, and receipt verification. The caller's implementation worktree is code-only. If the control checkout or mapping is absent, ambiguous, or unsafe, return `WAIT`/a capability diagnostic; never fall back to the feature-worktree copy. Source-only scope enumerates the complete project. Map provider IDs, body, status, priority/order, dependencies, and checkpoints into `ItemState`, retaining opaque fields. Merge the canonical helper item-claim status. Pass explicit review-group selectors unchanged to the supported provider operation; require exact ordered members and a stable group identity.

**Mutation:** With the CLI installed, use a fenced item claim and run each provider mutation from the canonical control checkout as one `backlog-claim exec ... -- backlog ...` operation. With only authorized MCP mutation, acquire the same canonical resource as `local-coordination` and apply the pre/post checks in [`claims.md`](claims.md). After acquisition, checkpoint visible ownership and `in-progress` state canonically before creating implementation isolation. `backlog-claim exec` wraps each shared provider write in the short provider/repository mutation transaction lock; run one exact-path provider-state commit or Git integration command with `backlog-claim control-exec ... -- git ...` under the same lock. Never hold it while coding or reviewing. It is distinct from the item claim and is same-host serialization only. Project ownership as `@<assignee>`, using `BACKLOG_CLAIM_ASSIGNEE` or stable `agentID`; assignment is never the claim. Persist every coherent pass's specification/progress/review/group checkpoint canonically before release, and retain provider plus claim/pre-post receipts. `mode:spec-only` changes specification content only and leaves progress unchanged. Failed/ambiguous operations remain incomplete.

**Archive:** Use the authorized provider archive/complete operation under the selected claim mode. Never rename/remove project files or archive every task merely because source-only discovery enumerated them.
