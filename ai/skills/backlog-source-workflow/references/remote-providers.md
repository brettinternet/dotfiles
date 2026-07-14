# Remote Providers

Load only the selected provider heading. Remote state is authoritative; local snapshots are temporary and read-only.

## Linear

Use only authenticated first-party Linear tooling, including its configured MCP integration. Never use raw HTTP, scraping, or local fallback state.

**Discovery:** Resolve exact team/project/issue identities; ambiguous unqualified identifiers require clarification. Repository detection requires one configured Linear source. Enumerate every page in a source-only collection. Map IDs, description, workflow state, priority/order, relations, and checkpoints into `ItemState`; retain UUID, URL, timestamps, and concurrency fields. Pass explicit review-group selectors unchanged and require exact members plus supported durable markers.

**Claims and mutation:** Use native fencing only when Linear provides conditional acquisition, authority time, claim revision, renewal/release, recovery, and fencing on actual writes. Otherwise use the canonical helper item resource as `local-coordination` and follow [`claims.md`](claims.md). After acquisition, assign an unassigned issue to the authenticated user; preserve a different assignee and stop. Use first-party update/comment/state operations, preserving unpatched fields and retaining remote version receipts. Persist caller-authorized progress markers through Linear; `mode:spec-only` leaves progress/workflow state unchanged. Never run Linear calls through `backlog-claim exec` or call assignment a claim.

**Archive:** Use the authorized first-party completion/archive operation and preserve that distinction. Never delete or create a local replacement.

## GitHub Issues

Use `gh` for every GitHub operation. Never construct raw requests outside `gh` or substitute repository files for issue state.

**Discovery:** Resolve an exact repository/issue locator; a bare number needs a repository. Repository detection requires one unambiguous origin/configured repository. Enumerate the complete collection with an explicit high limit and pagination (for example `gh issue list --state all --limit 1000`), diagnosing exhausted unknown bounds. Use `gh issue view` for full state. Derive and merge the canonical helper item claim. Extract dependencies only from native relations exposed through `gh` or documented issue-body vocabulary; keep malformed declared references unresolved instead of inferring from arbitrary prose, labels, titles, or incidental `#` references. Resolve explicit review groups only through a documented repository/provider convention with exact members and durable markers.

**Mutation:** Use the fenced helper item claim. Refresh the issue, then run each `gh` mutation as one `backlog-claim exec ... -- gh ...` operation; retain helper revision and resulting issue state. `gh api --paginate` is allowed for reads. Persist caller-authorized progress through the repository convention; `mode:spec-only` leaves progress/workflow state unchanged. Failed/ambiguous writes remain incomplete until reconciled or expiry. An unavailable helper, CLI, or authorized `gh` mutation is capability `none`; never downgrade GitHub writes to local coordination or bypass `gh`. Never treat comments, labels, assignees, Projects status, branches, or issue locks as claim state.

**Archive:** GitHub's archive equivalent is `gh issue close` under the claim. Never delete issues or close a whole collection because source-only discovery enumerated it.

## Future providers

Implement unambiguous resolution, complete discovery, normalized state/dependencies/order, durable first-party writes, explicit review groups, and archive. Prefer native fencing; otherwise derive a canonical coordination-only resource and follow [`claims.md`](claims.md). Return capability `none` only when required provider operations or canonical same-host coordination are unavailable. Never create writable shadow state or overstate the guarantee.
