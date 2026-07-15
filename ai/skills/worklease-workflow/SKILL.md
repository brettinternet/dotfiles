---
name: worklease-workflow
description: Coordinate generic work items from Backlog.md, Markdown, GitHub Issues, Linear, Jira, or custom sources with dependency-aware selection, bounded claims, durable progress, review boundaries, and archive operations. Use when an agent needs a safe Worklease loop without assuming a backend or provider.
---

# Worklease Workflow

Use this skill when a caller needs a safe work loop around an arbitrary backlog, queue, issue system, document set, or other work source. It is a coordination contract, not a provider integration or a claim-service implementation. The caller remains responsible for connecting the contract to its own source, authentication, mutation APIs, canonical claim resources, and authority.

This skill does not discover, name, select, or configure providers. It does not prescribe a command, storage engine, credential model, status vocabulary, transport, or fencing implementation. Source locators, item IDs, statuses, metadata, and receipts are opaque caller-owned values.

## Progressive loading

1. Read [`references/contract.md`](references/contract.md) before designing or executing a workflow.
2. When caller context does not already implement the source/provider capability object, read [`references/source-workflow.md`](references/source-workflow.md) and load only the matching provider reference.
3. Declare source resolution, discovery, reads, writes, caller-supplied opaque claim resources, claim reads and authority, and any review/archive operations.
4. Map the caller's source and claim service to the normalized contract without leaking backend assumptions into scheduling logic.
5. Use only capabilities the caller explicitly authorizes. A missing capability is a structured result, never an invented fallback.

## Worklease capability boundary

When the caller uses this repository's `worklease` package, map only the capabilities the tool actually supplies. `LeaseStore` can acquire, inspect, heartbeat, and release a bounded claim for one exact opaque `resource`; `worklease exec` and `worklease replace-file` can guard one local operation under that claim. The core lease service does not discover provider items, interpret statuses or dependencies, select work, authenticate to a provider, write provider progress, establish review boundaries, or archive provider data.
`LeaseStore.checkpoint` and the `worklease checkpoint` command can persist a bounded coordination checkpoint and renew the active claim. That value is local recovery metadata, not provider progress; the caller still verifies its authoritative provider checkpoint before release.

The bundled `worklease.adapters` are deterministic resource-identity and local-capability policies for a caller-selected provider, source, and item. They may supply the exact opaque resource and declared local scope. They do not discover provider work, execute provider writes, or establish provider-side fencing.

For work spanning several exact resources, use the bundle lifecycle when the caller needs all-or-nothing ownership. A bundle has 1–32 non-empty opaque resources, rejects exact duplicates, preserves caller order in receipts, and acquires locks in deterministic internal order. `acquire-bundle`, `heartbeat-bundle`, `exec-bundle`, `inspect-operation-bundle`, `reconcile-operation-bundle`, `release-bundle`, and `status-bundle` authorize the complete ordered member set with one shared claim ID, token, and revision; a member cannot be mutated through the single-resource API. Conflicts, expiry reclaim, and storage failures leave no partial bundle. This extends same-host coordination only: it does not add cross-host exclusion or provider-side fencing, and provider checkpoints remain caller/provider-owned.

The caller or a bundled/external provider adapter must supply the canonical resource before acquisition. Every contender for the same logical target and operation scope must produce the same exact string; the lease core deliberately does not normalize or interpret it. Retain that resource with the claim receipt for every status, heartbeat, guarded operation, and release.

Worklease emits `guarantee: fenced` for a normal claim but does not emit the normalized `guaranteeScope`; the caller or adapter must record that scope alongside the receipt. For Worklease, it is the matching guarded local `exec` or `replace-file` operation among cooperating callers on one host. Running a provider CLI or remote API inside that local operation does not create provider-side compare-and-set or cross-host fencing. When the durable provider mutation occurs outside that guarded local operation, report it as `local-coordination` unless the provider mutation itself supplies conditional-write or fencing evidence. Use a coordination-only claim when Worklease only excludes cooperating local schedulers and the durable mutation occurs outside a supported guarded operation.

A successful Worklease operation receipt is not by itself a durable provider checkpoint. The caller must retain the provider receipt or re-read the authoritative source and verify the expected version/state before checkpointing or release.

Checkpoint-before-release is a caller-enforced precondition. Worklease validates the exact ownership epoch and a non-blank audit reason; it does not inspect or verify a provider checkpoint.

## Provider integration boundary

If the caller's existing context does not already implement the capability object, load [`references/source-workflow.md`](references/source-workflow.md) after the generic contract. That layer owns source detection and resolution, source-qualified item/status/dependency/order mapping, authenticated provider reads and writes, durable provider receipts, and provider-specific review/archive behavior; it may use a bundled Worklease key adapter for canonical resource and local-capability policy. It records `providerMutationFenced: false` unless the provider mutation itself supplies fencing evidence. It must reuse this contract's graph construction, selection, ownership, and checkpoint-ordering invariants rather than restating them. Bundled key adapters do not replace this workflow layer. Load only the mappings for the providers actually resolved.

## Responsibility boundary

The caller owns command scope, authority, source-specific interpretation, canonical claim-resource mapping, and durable provider writes. This skill owns the coordination invariants:

- resolve all explicit sources and selectors in caller order;
- discover the complete dependency graph before selecting work;
- select only terminal-prerequisite, unblocked, claimable work;
- claim the exact canonical resource before delegation, isolation, or edits;
- heartbeat bounded leases while work is active;
- revalidate eligibility, ownership, guarantee scope, and provider state before durable mutations;
- verify a durable provider checkpoint before release or handoff; and
- keep review and archive boundaries explicit.

A caller may use Worklease or another local lease service, but it must report the guarantee and exact scope it actually has. Same-host coordination among cooperating callers is not cross-host exclusion, provider-side compare-and-set, or provider-mutation fencing.

## Normalized operating loop

1. Resolve the ordered source and item arguments.
2. Discover all scoped items and any dependencies required to establish readiness.
3. Build and validate the dependency graph. Missing references and cycles block the affected work.
4. Return `complete`, `blocked`, or `active-claims` when no item can be selected; do not skip a gate to manufacture work.
5. Select one item or a dependency-ready wave.
6. Accept one exact caller-supplied claim resource and acquire a fresh ownership epoch before handing off or editing.
7. Retain the exact resource, claim ID, token, revision, expiry, and guarantee; record the caller-declared guarantee scope alongside the receipt.
8. Revalidate dependencies, claim ownership, and provider state immediately before each durable write.
9. Heartbeat before half the lease elapses and around long-running operations.
10. Record and verify a durable checkpoint through the caller's provider write capability.
11. Review or archive only at an explicit authorized boundary.
12. Release only the exact current claim after the provider checkpoint succeeds.

Checkpoint-before-release is caller policy; the release reason is audit metadata, not checkpoint proof.

On interruption, let the bounded claim expire or perform an explicit coherent handoff. A resumed attempt receives a fresh claim ID and token; it never adopts an unexpired claim merely because the agent identity is unchanged.

## Safe failure behavior

Return structured diagnostics for `blocked`, `active-claims`, `conflict`, `ambiguous`, `ineligible`, `capability`, and `complete`. Preserve source and selector order in both success and failure results. Stop when the canonical resource, ownership, eligibility, guarantee scope, durable provider write, or receipt is uncertain. Never use an assignee, status, comment, branch, worktree, ordinary lock, local writable shadow, or local operation receipt as a substitute for a claim or verified provider checkpoint.

Display only non-secret claim metadata: resource, claim ID, revision, expiry, authority, guarantee, and guarantee scope. Pass the bearer token only to claim mutations or guarded operations; never include it in diagnostics, checkpoints, logs, or handoffs.

`worklease status --resource RESOURCE --verbose` is a read-only crash-diagnostic projection with `schemaVersion`, `ok`, `operation`, `resource`, `state`, `claim`, `unknownOperations`, `release`, and conditional `guidance` fields. It may report `free`, `active`, or `expired` state plus non-secret claim metadata, unresolved started-operation summaries, and latest release metadata. It must never expose bearer tokens, raw requests or receipts, command output, provider payloads, file contents, checkpoints, or completed operation receipts, and it must not reclaim, adopt, reconcile, heartbeat, release, or otherwise mutate state. Started operations represent unknown outcomes: inspect the authoritative provider before retrying and use the separate reconciliation flow when authorized. `reclaimed` is reported by acquire only and is not persisted historical diagnostic state. After expiry, acquire a fresh claim and token; retain the existing local-coordination or provider-fencing guarantee and never describe local coordination as provider-side or cross-host fencing.

For an unknown `exec-bundle` outcome, pass the exact ordered member set to `inspect-operation-bundle`, verify the authoritative result, and use `reconcile-operation-bundle` under the exact current bundle claim. Bundle reconciliation is atomic across members, advances the shared revision, and does not reveal the bearer token.

## Human and agent use

Humans can use this contract to review a work system's coordination guarantees and to implement a small adapter without changing scheduling rules. Agents should load the contract before provider mappings, keep the caller's task system authoritative, show the exact opaque claim resource and guarantee scope they hold, and leave durable progress where the provider can discover it. This skill neither authorizes nor implements backing-source edits; an authorized caller or adapter may mutate only through its declared durable write capability.
