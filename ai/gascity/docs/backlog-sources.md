# Backlog sources

This document defines the standalone backlog-source contract used by the sidecar.
The v1 Markdown adapter is intentionally read-only: preview and materialization
never write the configured source. A later, explicit write-back command owns any
source mutation.

## Markdown v1 grammar

The configured file defaults to `backlog.md`. Every task is a level-two ATX
section: a line beginning with `## ` followed by a non-empty title. The section
continues until the next `## ` heading (level-three and deeper headings are body
content). Text before the first task is ignored.

```markdown
## Optional title

<!-- id: stable-id -->
Status: done
Depends on: another-id, independent-id

The remaining section body is task content.
```

* `<!-- id: xyz -->` is optional and may occur once anywhere in the section. It
  wins over title-derived identity. IDs contain letters, numbers, `.`, `_`, `:`
  and `-`, and must start with a letter or number.
* Without an explicit marker, the ID is the title slug: lowercase ASCII, runs of
  punctuation/whitespace replaced by one `-`, and surrounding `-` removed.
  Duplicate explicit IDs or duplicate resolved IDs (including slug collisions)
  are typed errors and refuse the entire import; IDs are never disambiguated.
* The external reference is `md:<relative-path>#<id>`. A configured relative
  path is used as-is with POSIX separators. An absolute path supplied by a test
  or local caller contributes only its basename, so machine-local prefixes never
  enter a task reference.
* The fingerprint is the lowercase hexadecimal SHA-256 digest of the normalized
  section body (everything after the task heading, including an ID marker).
  Normalization converts CRLF/CR to LF, removes trailing spaces/tabs on each
  line, and removes leading/trailing blank lines. Internal content and blank
  lines are preserved. For the tracked fixture's conventional `KEY — human
  title` headings, the leading key is treated as the title slug (for example,
  `FIX-DEP — Add a greeting check` resolves to `fix-dep`). This keeps the
  fixture's dependency references stable while retaining the complete heading as
  `Task.title`.
* Dependencies are read from `Depends on: <id>[, <id>]` lines (case-insensitive,
  with optional indentation). IDs resolve case-insensitively so the fixture's
  uppercase dependency key can reference its lowercase slug. A missing task ID
  is a typed error. Dependencies are returned in declaration order.
* v1 done detection uses a section-level `Status:` line, not acceptance-criteria
  checkboxes. `done`, `complete`, `completed`, and `closed` (case-insensitive)
  mean done; any other non-empty status means not done. More than one status line,
  an empty status, malformed headings, IDs, or dependency IDs are typed errors.
* A task is actionable exactly when it is not done and every declared dependency
  is done. A task with no dependencies is actionable when not done.

The tracked `fixtures/backlog.md` is the primary fixture. Its `FIX-DEP` and
`FIX-INDEPENDENT` sections are actionable; `FIX-REVIEW` is not actionable until
`FIX-DEP` is marked done. Existing acceptance-criteria checkboxes do not affect
this result because v1 uses `Status:`.

## Python interface

The package lives at `sidecar/src/gascity_sidecar/backlog/` and has no HTTP or
FastAPI imports. `BacklogSource` defines the source boundary:

```python
class BacklogSource(ABC):
    def preview(self) -> list[Task]: ...
    def materialize(self, task_id: str) -> Task: ...
    def writeback(self, task_id: str, state: TaskState) -> None: ...
```

`Task` is an immutable value with `id`, `title`, normalized `body`,
`external_ref`, `fingerprint`, `dependencies`, `done`, `actionable`, and source
`section_number`. `TaskState` is the future write-back state model. The Markdown
adapter implements `preview` and pure-read `materialize`; `writeback` raises the
typed `ReadOnlySourceError`. `parse_markdown(text, source_path=...)` and
`MarkdownBacklog.from_text(...)` provide an in-memory parser path for tests.

Expected failures derive from `BacklogError`: malformed input raises
`MalformedBacklogError`, identity collisions raise `DuplicateTaskIdError`, and
missing dependencies raise `MissingDependencyError`.

## Future adapter fixtures (payloads only)

Future adapters should map their provider payload to the same `Task` fields and
must preserve the provider's stable identity in `external_ref`. These examples
are interface fixtures, not production integrations or authentication guidance.

### Linear-like payload

```json
{
  "id": "lin_123",
  "identifier": "ENG-42",
  "title": "Improve greeting output",
  "description": "Keep the output deterministic.",
  "state": {"type": "started", "name": "In Progress"},
  "blockedBy": [{"id": "lin_100", "identifier": "ENG-40"}],
  "updatedAt": "2026-07-17T12:00:00Z"
}
```

A Linear adapter would expose `external_ref` such as
`linear:lin_123#ENG-42`, map a completed state to `done=True`, map
`blockedBy` IDs to `dependencies`, and fingerprint the normalized description.

### Jira-like payload

```json
{
  "id": "10042",
  "key": "ENG-42",
  "fields": {
    "summary": "Improve greeting output",
    "description": "Keep the output deterministic.",
    "status": {"name": "In Progress", "statusCategory": {"key": "indeterminate"}},
    "issuelinks": [{"type": "Blocks", "outwardIssue": {"key": "ENG-40"}}]
  }
}
```

A Jira adapter would expose `external_ref` such as `jira:10042#ENG-42`, map the
status category to `done`, map blocking links to dependencies, and fingerprint a
normalized description. Provider-specific HTTP clients, credentials, and
write-back behavior are deliberately outside these fixtures and this package.
