---
description: List the next backlog items in execution order and identify item-level parallelism
argument-hint: [backlog-source|remote-ref] [item-ids|titles|ranges|description]
---

List the next open backlog units in recommended execution order and indicate whether each unit can run in parallel with another listed unit. `$ARGUMENTS` is optional and may contain local backlog paths, remote backlog references (such as Linear project names, issue IDs, or URLs), or selectors such as item IDs, titles, ranges, or a natural-language description.

This is a read-only prioritization command. Do not implement work, edit or create local backlog/spec/planning files, or update remote items, comments, or statuses.

## Resolve the backlog source

Apply the `backlog-source-workflow` skill as the shared source-resolution, provider-dispatch, and claim-authority contract. Load its provider-neutral contract first, then one matching provider heading per resolved kind. It normalizes `Source`, `SchedulingScope`, `ItemState`, `WorkClaim`, and optional `ReviewGroup`. This command is read-only: inspect provider state and `backlog-claim status` where selected, but never acquire, heartbeat, release, or mutate a claim.

Keep collection scope separate from item selection:

- A collection source is a loose Markdown backlog file, a whole Backlog.md project directory, a Linear project or issue set, or a GitHub Issues repository/project/query resolved through the provider's first-party integration. Source-only scope means the entire resolved collection; do not silently choose one item.
- An item ID, title, range, or description is a selector within the preceding collection source. An item ID that follows an already resolved source is never a second source. Exact item ID takes precedence over title, then description.
- Classify path-shaped arguments and recognized remote references before parsing selectors. Validate explicit sources left-to-right. A missing explicit local source path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported; a malformed or otherwise unresolved explicit source remains unresolved. Never drop an explicit source, substitute an unrelated source, or use a partial result.

Provider resolution is deliberately narrow: read loose Markdown using its existing structure; discover Backlog.md through supported CLI/MCP reads; use first-party Linear tooling; use `gh` for GitHub Issues; and merge same-host claim status from the resource key defined by the selected provider section. If an integration or local claim helper required to report authoritative eligibility is unavailable, report that limitation. Do not infer active ownership from assignees, labels, comments, statuses, branches, or stale local mentions.

When `$ARGUMENTS` contains no explicit source (including selector-only or description-only arguments), derive at most one active source from repository context in this order: repository-declared source or convention; structurally recognizable local backlog source matching the repository, branch, task, or selectors; then a remote collection linked by repository metadata or matching the selectors. Repository derivation happens only when no explicit source was supplied. If several derived sources are equally plausible, do not merge them; emit the diagnostic output below. When explicit sources are supplied, keep them distinct and include them in their supplied order.

## Determine units, order, and parallelism

- Read enough context to determine each unit's boundary, status, priority, dependencies, dependency-gated readiness, blockers, refinement/review progress, item/source claim, and implementation surface. Build the complete dependency graph before ordering.
- Treat a remote ticket or issue as one unit. For local markdown, use the established top-level work-item boundary; if the file itself is a standalone work spec, the whole file is one unit. Nested checklist entries, acceptance criteria, implementation steps, and other subitems are never separate units.
- Include open, review-pending, and in-progress units; exclude terminal units. A unit whose prerequisite is another defined but unfinished backlog item is dependency-gated and remains visible but ineligible; do not label it blocked. Provider-blocked units and units covered by an active item/source claim remain visible but ineligible. An expired claim is resumable only through a fresh claim ID.
- Order prerequisites before dependents. Within the earliest dependency-ready wave, order unclaimed/expired-claim review-pending or in-progress work before new work. Explicit selector/source order remains authoritative; provider priority, ordinal/order, then stable ID rank only source-only items within one source and wave. Keep provider-blocked, missing/cyclic roots, and actively claimed roots visible with every dependent chain they gate; never move a dependent into an earlier wave because its prerequisite is claimed or label a dependent blocked solely because its prerequisite is unfinished.
- Mark parallelizable only unclaimed units ready in the same wave with no dependency/shared migration/schema/interface/stateful resource/ownership. A blocker or active item/source claim means `Parallel: no`; a source claim applies its owner/expiry to every unit in that source.

## Output

On successful resolution, output only:

`Sources: <all resolved local paths and remote projects/queries, in resolution order>`
`Substituted: <requested local path> -> <adjacent candidate>` for each permitted adjacent-path substitution, in argument order; omit this line when no substitution occurred.

Then one numbered line per unit:

`<order>. [<source>] <unit ID or backlog filename> — <title> — Claim: <unclaimed | expired/resumable | item/source owner until expiry> — Parallel: <no | yes, with #N[, #N...]> — <brief ordering reason>`

Use each source's identifiers/titles and include the source label even when only one source resolved. Keep the reason to one short dependency, dependency-gated readiness, blocker, claim, resumable-progress, or priority/order phrase. If no open units match, output the resolved sources and `No open backlog units found.` If open units exist but no item is claimable, add `No claimable backlog units: <provider-blocked/missing/cyclic roots, dependency-gated chains, and/or active claim owners/expiries>.` Do not add an implementation plan, expand units into subitems, or suggest sequencing within a unit.

On a source-resolution failure, unresolved selector, or ambiguous derived source, output only:

`Sources: unresolved`
`Problem: <unresolved path, remote reference/integration, selector and searched source, or ambiguity>`
`Candidates: <candidate sources>` (ambiguity only)
`Needed to choose: <missing evidence>` (ambiguity only)

Do not emit numbered unit lines for diagnostic output.
