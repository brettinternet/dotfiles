# Remote provider sections

Load only the heading for each provider selected by `references/contract.md`. Remote provider state is authoritative. Repository Markdown or an API/cache snapshot may be used only as read-only temporary context; it is never a writable shadow backlog, fallback source, progress marker, review marker, dependency store, or completion store.

## Linear

Linear sources are resolved and operated through the authenticated first-party Linear integration/tooling (including its MCP operations when that is the repository's configured integration). Do not use raw HTTP calls, scrape a web page, or replace an unavailable integration with local files.

### Discovery

- An explicit Linear team, project, issue identifier, or URL resolves to its exact team/project/issue and supplies the source locator. An unqualified identifier that could be a local item, GitHub issue, or another Linear object is ambiguous until the first-party integration identifies one exact object.
- Repository-derived Linear detection is allowed only from an unambiguous configured Linear source. If configuration names multiple teams/projects, report candidates instead of choosing one.
- `discover` with no selector enumerates the complete resolved collection (for example, every issue in a project or the configured team), including all pages/results exposed by the integration. Source-only scope therefore covers the whole project/team collection, not only the first actionable issue.
- Map Linear issue IDs, title/description, workflow state, priority, project/team order, dependencies/relations, and review metadata into `ItemState`. Keep the Linear UUID, URL, timestamps, and version/concurrency fields in `providerData` so writes target the same remote item.
- An explicit `review-group:<provider-native-selector>` is passed to the Linear integration unchanged. The integration must resolve the exact member IDs and support the authorized durable group marker; otherwise return a capability/invalid-selector diagnostic rather than using the one-item default or a local marker.

### Durable mutation and progress

- Use first-party Linear update/comment/state operations for task progress, implementation state, review state, dependency changes, and completion. Preserve existing remote fields not named by the patch.
- Every write requires the caller's authority and exact item or explicitly authorized `ReviewGroup`. Verify the current remote item before a mutation where the integration provides a version or updated timestamp; retain the returned remote ID/version as the durable receipt.
- Post progress where the command's contract requires it (for example, an `implemented:`, `reviewed:`, or `blocked:` comment) using the Linear integration. Do not record authoritative progress only in a handoff or local snapshot. If the integration cannot write, leave the item incomplete and report the durable-write failure.

### Archive

Use Linear's first-party archive/completion operation when authorized. If the integration distinguishes completed from archived, preserve that distinction in `ItemState` and use the operation requested by the caller. Never delete an issue, create a local replacement, or archive a whole project because it appeared in a source-only schedule.

## GitHub Issues

The GitHub Issues provider uses the `gh` CLI for all GitHub operations. Do not construct API calls outside `gh`, edit repository files as a substitute for issue state, or use an unapproved local mirror.

### Discovery

- Resolve an explicit repository/issue locator (`owner/repo#number`, issue URL, or repository plus issue selector) through `gh`. A bare issue number is ambiguous without a repository; report the candidate repositories instead of guessing.
- Repository-derived detection uses the unambiguous GitHub `origin` repository (or an explicitly configured repository). Multiple remotes/repositories require an explicit locator. A source is the repository's issue collection, optionally narrowed only by an explicit caller selector.
- Enumerate the complete resolved collection, including open and closed issues, with an explicit non-default bound such as `gh issue list --state all --limit 1000` (or a configured higher complete bound). When the selected `gh` listing endpoint exposes pages, use its supported pagination (including `gh api --paginate` where needed) and continue until the provider reports no next page; a first page or exhausted limit that is not known to be complete is a diagnostic, not successful discovery. Fetch each issue with `gh issue view` as needed for full machine-readable fields.
- Extract dependencies only from provider/repository-declared native relations exposed by `gh` or from an explicitly documented issue-body vocabulary. If neither exists, set `dependencies` empty and do not infer edges from arbitrary prose, labels, titles, or incidental `#` references. When a declared relation or body reference is malformed, retain it as an unresolved dependency and emit the contract's blocking diagnostic rather than dropping or treating it as complete.
- For `review-group:<provider-native-selector>`, pass the selector to the repository's supported GitHub group convention (for example a documented milestone/parent selector), resolve and retain every member issue number in order, and require an authorized durable group marker. If GitHub or the repository convention cannot resolve or persist it, return a capability/invalid-selector diagnostic; never infer membership or use a local marker.

### Durable mutation and progress

- Use `gh issue view`, `gh issue edit`, `gh issue comment`, and other supported `gh issue` operations for reads, edits, progress comments, labels, and state changes. If pagination requires `gh api --paginate`, it must still run through the documented `gh` command; do not use curl or a separately constructed GraphQL/REST request.
- `gh` writes require the caller's authority and exact issue/review scope. Read the current issue before changing it when practical, preserve fields outside the requested patch, and retain the command result/issue state as the durable receipt.
- Record required `implemented:`, `reviewed:`, or `blocked:` progress as an issue comment (or the caller-authorized native field) before advancing. If `gh` is unavailable, unauthenticated, or the write fails, do not claim completion and do not substitute a local marker.

### Archive

GitHub has no separate archive for an issue in this contract: the authorized archive equivalent is closing the issue with `gh issue close` and retaining the closed state/number as the receipt. Do not delete issues, close an entire repository's collection because it was enumerated, or interpret a source-only schedule as authorization to close every issue.

## Future providers

A future remote provider must expose the same normalized operations and values in `references/contract.md`: unambiguous source resolution, complete source discovery, dependency/status/order mapping, durable provider-native reads and writes, explicit one-item review default, explicit larger-group review, progress recording, and archive. Use its authenticated first-party tooling where available and keep durable state in that provider. Add a new provider heading rather than changing commands or this normalized interface; return a capability error for unsupported operations instead of using a local shadow store or an unapproved fallback.
