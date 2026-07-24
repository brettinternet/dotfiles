# Backlog sources

This document defines the standalone backlog-source contract used by the sidecar.
Preview and materialization never write the configured source. An explicit
write-back command owns source mutation and is guarded by the current source
fingerprint plus the accepted/closed Beads state.

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

- `<!-- id: xyz -->` is optional and may occur once anywhere in the section. It
  wins over title-derived identity. IDs contain letters, numbers, `.`, `_`, `:`
  and `-`, and must start with a letter or number.
- Without an explicit marker, the ID is the title slug: lowercase ASCII, runs of
  punctuation/whitespace replaced by one `-`, and surrounding `-` removed.
  Duplicate explicit IDs or duplicate resolved IDs (including slug collisions)
  are typed errors and refuse the entire import; IDs are never disambiguated.
- The external reference is `md:<relative-path>#<id>`. A configured relative
  path is used as-is with POSIX separators. An absolute path supplied by a test
  or local caller contributes only its basename, so machine-local prefixes never
  enter a task reference.
- The fingerprint is the lowercase hexadecimal SHA-256 digest of the normalized
  section body (everything after the task heading, including an ID marker).
  Normalization converts CRLF/CR to LF, removes trailing spaces/tabs on each
  line, and removes leading/trailing blank lines. Internal content and blank
  lines are preserved. For headings in the tracked fixture's conventional
  `KEY — title` form, the leading key is treated as the title slug (for example,
  `FIX-DEP — Add a greeting check` resolves to `fix-dep`). This keeps the
  fixture's dependency references stable while retaining the complete heading as
  `Task.title`.
- Dependencies are read from `Depends on: <id>[, <id>]` lines (case-insensitive,
  with optional indentation). IDs resolve case-insensitively so the fixture's
  uppercase dependency key can reference its lowercase slug. A missing task ID
  is a typed error. Dependencies are returned in declaration order.
- v1 done detection uses a section-level `Status:` line, not acceptance-criteria
  checkboxes. `done`, `complete`, `completed`, and `closed` (case-insensitive)
  mean done; any other non-empty status means not done. More than one status line,
  an empty status, malformed headings, IDs, or dependency IDs are typed errors.
- A task is actionable exactly when it is not done and every declared dependency
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
`section_number`. `TaskState` carries the completion flag plus source metadata
needed by guarded writeback. The Markdown adapter implements pure-read
`preview`/`materialize` and explicit `writeback`: it verifies the recorded
fingerprint, inserts or updates `Status: done`, and atomically replaces the
source while preserving unrelated bytes. The in-memory test adapter remains
read-only. `parse_markdown(text, source_path=...)` and
`MarkdownBacklog.from_text(...)` provide an in-memory parser path for tests.

Expected failures derive from `BacklogError`: malformed input raises
`MalformedBacklogError`, identity collisions raise `DuplicateTaskIdError`, and
missing dependencies raise `MissingDependencyError`.

## Add a repository as a rig

The source adapter has no persistent source registry. Configure each invocation
with `GC_BACKLOG_SOURCE` and `GC_BACKLOG_RELATIVE_PATH`, or pass the equivalent
`--source` and `--relative-path` CLI options. Keep machine-local values in the
ignored city `.env` or in the invoking shell; never commit absolute paths.

The HTTP preview/import endpoints accept only paths beneath
`GC_SIDECAR_CITY_PATH`. For an arbitrary external rig, run the tracked wrappers
from the rig directory as shown below. They execute the same sidecar adapter and
use that directory's Beads database. The HTTP API remains appropriate for a
source stored inside the city.

### Register and inspect

From the Gas City directory:

```sh
CITY_DIR=$PWD
RIG_DIR=/path/to/repository
RIG_NAME=my-repository
RIG_PREFIX=myrepo

test -d "$RIG_DIR/.git"
test -f "$RIG_DIR/backlog.md"
git -C "$RIG_DIR" status --short

mise exec -- gc --city "$CITY_DIR" rig add "$RIG_DIR" \
  --name "$RIG_NAME" \
  --prefix "$RIG_PREFIX" \
  --default-branch main \
  --include .
mise exec -- gc --city "$CITY_DIR" rig list --json
```

Choose the repository's actual mainline branch instead of `main` when needed.
`gc rig add` initializes Beads, installs configured hooks, writes the portable
rig registration to `city.toml`, and creates machine-local binding/runtime
state. Use `--adopt` only when the repository already has a complete `.beads/`
directory. Use `--start-suspended` when registration must not start agents.
The installed v1.3.5 CLI names this local pack import `import`, so its intake
target is `<rig-name>/import.intake`.

Preview from the rig directory before any import:

```sh
cd "$RIG_DIR"
export GC_BACKLOG_SOURCE=backlog.md
export GC_BACKLOG_RELATIVE_PATH=backlog.md
"$CITY_DIR/commands/backlog-preview/run.sh"
git diff --exit-code -- backlog.md
```

The JSON array identifies stable task IDs and actionability. Preview performs no
Beads write and the final command proves the Markdown source did not change.
Fix any typed parse, duplicate-ID, or missing-dependency error before continuing.

### Import and dispatch one item

Select one actionable ID from preview:

```sh
TASK_ID=task-id-from-preview
IMPORT_JSON=$("$CITY_DIR/commands/backlog-import/run.sh" "$TASK_ID")
printf '%s\n' "$IMPORT_JSON"
git diff --exit-code -- backlog.md
```

Import creates or updates one Beads task and reconciles its dependencies. It is
idempotent by the portable external reference
`md:backlog.md#<task-id>` and does not edit the Markdown source. Read
`bead_id` and `external_ref` from `IMPORT_JSON`, then ask the loopback sidecar
to apply admission policy and dispatch the workflow:

```sh
BEAD_ID=$(printf '%s' "$IMPORT_JSON" | jq -r .bead_id)
EXTERNAL_REF=$(printf '%s' "$IMPORT_JSON" | jq -r .external_ref)

jq -n \
  --arg bead_id "$BEAD_ID" \
  --arg external_source_ref "$EXTERNAL_REF" \
  --arg target "$RIG_NAME/import.intake" \
  '{
    bead_id: $bead_id,
    external_source_ref: $external_source_ref,
    target: $target,
    provider: "omp"
  }' |
  curl --fail-with-body \
    --header 'content-type: application/json' \
    --data-binary @- \
    http://127.0.0.1:8787/workflows/dispatch
```

The sidecar may return `409 admission_refused` while paused or over budget.
Success returns the selected repair limit and Gas City dispatch result.
Dispatch does not write the external backlog. Completion reaches Markdown only
through the separate guarded `backlog-writeback` command after an accepted,
closed Beads outcome.

### Dry-run with a second generated fixture

This proves the registration and source steps without touching a real
repository or the canonical fixture:

```sh
cd "$CITY_DIR"
assets/scripts/make-fixture-rig.sh
git clone .local/fixture-rig .local/fixture-rig-gc17
RIG_DIR=$CITY_DIR/.local/fixture-rig-gc17
RIG_NAME=fixture-gc17
RIG_PREFIX=f17

mise exec -- gc --city "$CITY_DIR" rig add "$RIG_DIR" \
  --name "$RIG_NAME" \
  --prefix "$RIG_PREFIX" \
  --default-branch main \
  --include . \
  --start-suspended

cd "$RIG_DIR"
GC_BACKLOG_SOURCE=backlog.md \
GC_BACKLOG_RELATIVE_PATH=backlog.md \
"$CITY_DIR/commands/backlog-preview/run.sh"
IMPORT_JSON=$(GC_BACKLOG_SOURCE=backlog.md \
  GC_BACKLOG_RELATIVE_PATH=backlog.md \
  "$CITY_DIR/commands/backlog-import/run.sh" fix-independent)
BEAD_ID=$(printf '%s' "$IMPORT_JSON" | jq -r .bead_id)
mise exec -- gc --city "$CITY_DIR" --rig "$RIG_NAME" sling \
  "$RIG_NAME/import.intake" backlog-item --formula \
  --var "item=$BEAD_ID" --var max_repair_attempts=2 --dry-run --json
git diff --exit-code -- backlog.md
```

Expected results: `rig list` includes `fixture-gc17`; preview reports
`fix-independent` actionable; import reports `created` (or `updated` on a
repeat); and `backlog.md` remains byte-for-byte unchanged. The dry-run dispatch
returns `"dry_run": true`, `"success": true`, and target
`fixture-gc17/import.intake` without materializing a workflow. Resume the rig
and use the HTTP dispatch request above only for an end-to-end workflow.
Because `gc rig add` updates `city.toml`, use a disposable branch/worktree for
this proof or intentionally commit the new real-rig registration.

## Future adapter fixtures (payloads only)

Future adapters must implement the same `BacklogSource` boundary, map provider
payloads to `Task`, preserve stable provider identity in `external_ref`, and
retain preview/materialize/writeback separation. These payloads are contract
fixtures only, not production integrations.

### Linear-like payload

```json
{
  "id": "lin_123",
  "identifier": "ENG-42",
  "title": "Improve greeting output",
  "description": "Keep the output deterministic.",
  "state": { "type": "started", "name": "In Progress" },
  "blockedBy": [{ "id": "lin_100", "identifier": "ENG-40" }],
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
    "status": { "name": "In Progress", "statusCategory": { "key": "indeterminate" } },
    "issuelinks": [{ "type": "Blocks", "outwardIssue": { "key": "ENG-40" } }]
  }
}
```

A Jira adapter would expose `external_ref` such as `jira:10042#ENG-42`, map the
status category to `done`, map blocking links to dependencies, and fingerprint a
normalized description.

Any future HTTP client must receive credentials only from environment variables,
for example `GC_SIDECAR_LINEAR_TOKEN`, `GC_SIDECAR_JIRA_URL`,
`GC_SIDECAR_JIRA_USER`, and `GC_SIDECAR_JIRA_TOKEN`. Local values belong in the
ignored city `.env`; they never belong in `city.toml`, source metadata, fixture
payloads, logs, or the sidecar database. Token loading, pagination, rate limits,
remote writeback, and provider-specific clients remain unimplemented.
