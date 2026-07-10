---
description: List the next backlog items in execution order and identify item-level parallelism
argument-hint: [backlog-file|remote-ref] [item-ids|titles|ranges|description]
---

List the next open backlog units in recommended execution order and indicate whether each unit can run in parallel with another listed unit. `$ARGUMENTS` is optional and may contain local backlog paths, remote backlog references (such as Linear project names, issue IDs, or URLs), or selectors such as item IDs, titles, ranges, or a natural-language description.

This is a read-only prioritization command. Do not implement work, edit or create local backlog/spec/planning files, or update remote items, comments, or statuses.

## Resolve the backlog source

Resolve source-shaped inputs with this precedence:

1. **Local backlog:** use each supplied path that resolves to an existing local backlog file. A local file is a backlog only when its structure represents work units, not merely because it mentions an issue ID. If a path-shaped argument does not resolve to an existing backlog file, treat it as an unresolved explicit source; do not drop it or substitute a different source.
2. **Remote backlog:** before parsing selectors, classify a recognized remote URL, a system-qualified project reference, or a system-specific item ID as an explicit remote source. An item ID that follows an already resolved collection source is instead a selector within that source. Resolve explicit remote references with the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available. If a required remote integration is unavailable or unauthenticated, report that exact limitation instead of guessing from stale local mentions.
3. **Derived context:** when no source is supplied, or `$ARGUMENTS` contains only selectors or a description, derive and search for the active backlog from repository context. Check, in order: a repository-declared backlog source or convention; structurally recognizable local backlog files matching the current repository, branch, task, or selectors; then a remote project or issue set linked by repository metadata or matching the selectors. Use first-party remote search when the repository context identifies that system.

When multiple explicit sources are supplied, include all of them in the supplied order. When several derived sources remain equally plausible, do not merge unrelated backlogs. Never silently substitute a generic TODO list, arbitrary issue search, or completed/archive file for an active backlog.

Use selectors in `$ARGUMENTS` only to narrow the resolved source. An exact item ID takes precedence over a title match, which takes precedence over a description match. A source-resolution failure, unresolved selector, or ambiguous derived source uses the diagnostic output below; do not continue with a partial or guessed list.

## Determine units, order, and parallelism

- Read enough surrounding backlog and repository context to determine each unit's boundary, status, priority, dependencies, blockers, and likely implementation surface.
- Treat a remote ticket or issue as one unit. For local markdown, use the file's established top-level work-item boundary; if the file itself is a standalone work spec, the whole file is one unit. Nested checklist entries, acceptance criteria, implementation steps, and other subitems are never separate units in this output.
- Include open and in-progress units in scope; exclude completed, canceled, and archived units. Keep an in-progress unit first unless it is blocked.
- Honor explicit prerequisites and blockers before priority. Otherwise preserve each source's priority/rank and stable document or remote ordering. Across multiple sources, apply status and dependency ordering globally only when evidence links their units; otherwise use source resolution order as the deterministic tie-break without comparing unrelated priority scales. Do not infer sequencing merely from the order of nested subitems.
- Mark units parallelizable only when they are ready in the same ordering wave, neither depends on the other, and available evidence shows no shared migration, schema, central interface, stateful resource, or overlapping implementation ownership that requires coordination. Be conservative: insufficient evidence means `Parallel: no`, with that reason.
- A blocked unit is not parallel-ready. Place it after any listed prerequisite and identify the blocker in the ordering reason.

## Output

On successful resolution, output only:

`Sources: <all resolved local paths and remote projects/queries, in resolution order>`

Then one numbered line per unit:

`<order>. [<source>] <unit ID or backlog filename> — <title> — Parallel: <no | yes, with #N[, #N...]> — <brief ordering reason>`

Use each source's identifiers and titles, and include the source label even when only one source was resolved. Keep the reason to one short phrase explaining only a dependency, blocker, current in-progress state, or priority/order tie-break. Do not add an implementation plan, do not expand a unit into subitems, and do not suggest sequencing within a unit. If no open units match, output the resolved sources and `No open backlog units found.`

On a source-resolution failure, unresolved selector, or ambiguous derived source, output only:

`Sources: unresolved`
`Problem: <unresolved path, remote reference/integration, selector and searched source, or ambiguity>`
`Candidates: <candidate sources>` (ambiguity only)
`Needed to choose: <missing evidence>` (ambiguity only)

Do not emit numbered unit lines for diagnostic output.
