---
description: List the next backlog items in execution order and identify item-level parallelism
argument-hint: [backlog-source|remote-ref] [item-ids|titles|ranges|description]
---

List the next open backlog units in recommended execution order and indicate whether each unit can run in parallel with another listed unit. `$ARGUMENTS` is optional and may contain local backlog paths, remote backlog references (such as Linear project names, issue IDs, or URLs), or selectors such as item IDs, titles, ranges, or a natural-language description.

This is a read-only prioritization command. Do not implement work, edit or create local backlog/spec/planning files, or update remote items, comments, or statuses.

## Resolve the backlog source

Apply the `backlog-source-workflow` skill as the shared source-resolution and provider-dispatch contract. Load its provider-neutral contract first, then one matching provider heading for each resolved provider kind, preserving the explicit source order when sources use unrelated provider kinds. It normalizes `Source`, `SchedulingScope`, `ItemState`, and optional `ReviewGroup`, resolves explicit sources and selectors in argument order before deriving at most one unambiguous repository source, and progressively loads only those selected headings. Treat `review-group:` only as provider scope metadata when the selected provider supports it and the caller explicitly supplies it; never infer a `ReviewGroup` from source-only scope, labels, adjacency, or selector shape. The skill's default review boundary is exactly one implementation item; this command's read-only boundary, dependency-aware ordering, and output format override the skill where they are more specific.

Keep collection scope separate from item selection:

- A collection source is a loose Markdown backlog file, a whole Backlog.md project directory, a Linear project or issue set, or a GitHub Issues repository/project/query resolved through the provider's first-party integration. Source-only scope means the entire resolved collection; do not silently choose one item.
- An item ID, title, range, or description is a selector within the preceding collection source. An item ID that follows an already resolved source is never a second source. Exact item ID takes precedence over title, then description.
- Classify path-shaped arguments and recognized remote references before parsing selectors. Validate explicit sources left-to-right. A missing explicit local source path may substitute only one clearly adjacent same-directory or moved/renamed-basename candidate, and the substitution must be reported; a malformed or otherwise unresolved explicit source remains unresolved. Never drop an explicit source, substitute an unrelated source, or use a partial result.

Provider resolution is deliberately narrow: read loose Markdown using its existing structure; discover Backlog.md projects and task IDs through the project's supported CLI/MCP surface; use first-party Linear tooling; and use `gh` for GitHub Issues. If a required integration is unavailable or unauthenticated, report that exact limitation. Do not embed provider manuals or infer state from stale local mentions.

When `$ARGUMENTS` contains no explicit source (including selector-only or description-only arguments), derive at most one active source from repository context in this order: repository-declared source or convention; structurally recognizable local backlog source matching the repository, branch, task, or selectors; then a remote collection linked by repository metadata or matching the selectors. Repository derivation happens only when no explicit source was supplied. If several derived sources are equally plausible, do not merge them; emit the diagnostic output below. When explicit sources are supplied, keep them distinct and include them in their supplied order.

## Determine units, order, and parallelism

- Read enough surrounding backlog and repository context to determine each unit's boundary, status, priority, dependencies, blockers, and likely implementation surface.
- Treat a remote ticket or issue as one unit. For local markdown, use the file's established top-level work-item boundary; if the file itself is a standalone work spec, the whole file is one unit. Nested checklist entries, acceptance criteria, implementation steps, and other subitems are never separate units in this output.
- Include open, review-pending, and in-progress units; exclude completed, canceled, and archived units. Include blocked open units in the output, but they are not eligible or parallel-ready until their blocker is resolved.
- After determining review/state and dependency readiness, order review-pending/in-progress eligible work before other dependency-ready work. For explicitly selected items, preserve selector order within each resolved source; when comparing unrelated resolved sources, preserve explicit source order. For source-only collections, provider priority, then provider ordinal/order, then stable ID may rank items only within one source; never use those fields to reorder sources or explicitly selected items. Keep blocked open units visible after their listed prerequisites and all eligible/ready work, with the blocker named in the ordering reason.
- Mark units parallelizable only when they are ready in the same ordering wave, neither depends on the other, and evidence shows no shared migration, schema, central interface, stateful resource, or overlapping implementation ownership requiring coordination. Insufficient evidence means `Parallel: no`, with that reason. Blocked units always have `Parallel: no`; place them after listed prerequisites and ready work, and name the blocker in the ordering reason.

## Output

On successful resolution, output only:

`Sources: <all resolved local paths and remote projects/queries, in resolution order>`
`Substituted: <requested local path> -> <adjacent candidate>` for each permitted adjacent-path substitution, in argument order; omit this line when no substitution occurred.

Then one numbered line per unit:

`<order>. [<source>] <unit ID or backlog filename> — <title> — Parallel: <no | yes, with #N[, #N...]> — <brief ordering reason>`

Use each source's identifiers and titles, and include the source label even when only one source was resolved. Keep the reason to one short phrase explaining only a dependency, blocker, current in-progress state, or priority/order tie-break. Do not add an implementation plan, do not expand a unit into subitems, and do not suggest sequencing within a unit. If no open units match, output the resolved sources and `No open backlog units found.`

On a source-resolution failure, unresolved selector, or ambiguous derived source, output only:

`Sources: unresolved`
`Problem: <unresolved path, remote reference/integration, selector and searched source, or ambiguity>`
`Candidates: <candidate sources>` (ambiguity only)
`Needed to choose: <missing evidence>` (ambiguity only)

Do not emit numbered unit lines for diagnostic output.
