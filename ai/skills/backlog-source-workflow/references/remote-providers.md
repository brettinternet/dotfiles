# Remote provider sections

Load only the heading for each provider selected by `references/contract.md`. Remote provider state is authoritative. Repository Markdown or an API/cache snapshot may be used only as read-only temporary context; it is never a writable shadow backlog, fallback source, progress marker, review marker, dependency store, or completion store.

## Linear

Linear sources are resolved and operated through the authenticated first-party Linear integration/tooling (including its MCP operations when that is the repository's configured integration). Do not use raw HTTP calls, scrape a web page, or replace an unavailable integration with local files.

### Discovery

- An explicit Linear team, project, issue identifier, or URL resolves to its exact team/project/issue and supplies the source locator. An unqualified identifier that could be a local item, GitHub issue, or another Linear object is ambiguous until the first-party integration identifies one exact object.
- Repository-derived Linear detection is allowed only from an unambiguous configured Linear source. If configuration names multiple teams/projects, report candidates instead of choosing one.
- `discover` with no selector enumerates the complete resolved collection (for example, every issue in a project or the configured team), including all pages/results exposed by the integration. Source-only scope therefore covers the whole project/team collection, not only the first actionable issue.
- Map Linear issue IDs, title/description, workflow state, priority/order, dependencies/relations, and refinement/review checkpoints into `ItemState`. Keep UUID, URL, provider timestamps, and version/concurrency fields in `providerData`. The repository's local helper returns `unsupported-provider-claim` for Linear, so `claim` is null unless the configured first-party integration independently exposes the contract's complete native claim transaction.
- An explicit `review-group:<provider-native-selector>` is passed to the Linear integration unchanged. The integration must resolve the exact member IDs and support the authorized durable group marker; otherwise return a capability/invalid-selector diagnostic rather than using the one-item default or a local marker.

### Durable mutation and progress

- Use first-party Linear update/comment/state operations for task progress, implementation state, review state, dependency changes, and completion. Preserve existing remote fields not named by the patch.
- Every write requires the caller's authority and exact item or explicitly authorized `ReviewGroup`. Verify the current remote item before a mutation where the integration provides a version or updated timestamp; retain the returned remote ID/version as the durable receipt.
- Post required `refined:`, `implemented:`, `reviewed:`, or `blocked:` progress using the Linear integration. A normal refinement's `refined:` checkpoint names its specification receipt/version; `mode:spec-only` leaves progress unchanged. A handoff or claim release is not authoritative progress.
- Declare `item-claim` or fenced `source-claim` only when the configured first-party Linear integration itself supplies conditional acquisition, authority time, unique claim/revision, idempotent recovery, renew/release, and fencing on actual mutations. The same-host helper cannot wrap Linear MCP/tool calls and intentionally returns a capability error. Labels, assignees, comments, and workflow status are not claims; without complete native support, capability is `none` and mutating commands stop before work.

### Archive

Use Linear's first-party archive/completion operation when authorized. If the integration distinguishes completed from archived, preserve that distinction in `ItemState` and use the operation requested by the caller. Never delete an issue, create a local replacement, or archive a whole project because it appeared in a source-only schedule.

## GitHub Issues

The GitHub Issues provider uses the `gh` CLI for all GitHub operations. Do not construct API calls outside `gh`, edit repository files as a substitute for issue state, or use an unapproved local mirror.

### Discovery

- Resolve an explicit repository/issue locator (`owner/repo#number`, issue URL, or repository plus issue selector) through `gh`. A bare issue number is ambiguous without a repository; report the candidate repositories instead of guessing.
- Repository-derived detection uses the unambiguous GitHub `origin` repository (or an explicitly configured repository). Multiple remotes/repositories require an explicit locator. A source is the repository's issue collection, optionally narrowed only by an explicit caller selector.
- Enumerate the complete collection with an explicit non-default bound such as `gh issue list --state all --limit 1000` and supported pagination until no next page remains. Fetch issues with `gh issue view` as needed for full dependency and refinement/review state. For each issue, derive `backlog-claim key --provider github --source <host/owner/repo> --item <number>` and merge `backlog-claim status` into `ItemState`. An exhausted unknown bound is a diagnostic, not complete discovery.
- Extract dependencies only from provider/repository-declared native relations exposed by `gh` or from an explicitly documented issue-body vocabulary. If neither exists, set `dependencies` empty and do not infer edges from arbitrary prose, labels, titles, or incidental `#` references. When a declared relation or body reference is malformed, retain it as an unresolved dependency and emit the contract's blocking diagnostic rather than dropping or treating it as complete.
- For `review-group:<provider-native-selector>`, pass the selector to the repository's supported GitHub group convention (for example a documented milestone/parent selector), resolve and retain every member issue number in order, and require an authorized durable group marker. If GitHub or the repository convention cannot resolve or persist it, return a capability/invalid-selector diagnostic; never infer membership or use a local marker.

### Durable mutation and progress

- Use `gh issue view` for reads. Under a normal-mode claim, each `gh issue edit`, `gh issue comment`, close/reopen, progress, label, or other mutation runs as exactly one `backlog-claim exec ... -- gh ...` operation with the current issue claim. If pagination requires `gh api --paginate`, it remains a read through `gh`; do not use curl or a separately constructed request.
- `gh` writes require the caller's authority and exact issue/review scope. Refresh the current issue before the guarded mutation, preserve fields outside the requested patch, and retain both the helper receipt/new claim revision and resulting issue state. Failed or ambiguous commands leave the issue incomplete and the claim unreleased until reconciled or expired.
- Record required `refined:`, `implemented:`, `reviewed:`, or `blocked:` progress through the authorized repository convention inside the guard. A normal refinement's `refined:` checkpoint names its specification receipt/version; `mode:spec-only` leaves progress unchanged.
- Declare same-host `item-claim` through `backlog-claim`. The canonical host/repository/issue resource, claim CAS, guarded `gh` process, idempotent operation receipt, heartbeat, and release form the fence for cooperating agents on this host. Comments, labels, assignees, Projects status, branches, and issue locks are not claim state. An unavailable helper/CLI, direct unguarded write, cross-host worker without shared CAS, or mutation that cannot execute through `gh` is capability `none`.

### Archive

GitHub has no separate archive for an issue in this contract: the authorized archive equivalent is closing the issue with `gh issue close` under `backlog-claim exec` and retaining both receipts. Do not delete issues, close an entire repository's collection because it was enumerated, or interpret a source-only schedule as authorization to close every issue.

## Future providers

A future remote provider implements unambiguous resolution, complete discovery, dependency/status/order/refinement/review/claim mapping, `item-claim` or fenced `source-claim`, durable fenced writes/progress, review boundaries, and archive. Partial claim support is `none`; use authenticated first-party tooling, keep state provider-owned, and return capability errors instead of local/racy fallbacks.
