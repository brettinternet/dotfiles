# Workflow quick reference

Gas City processes one imported backlog item per dispatch. Each phase runs in a
fresh one-shot session:

```text
Markdown → Beads → intake → plan → implement ↔ review → verify → finalize
```

The implement/review repair loop is automatic. State passes through Beads
metadata and `.gascity/work/<workflow-root>/`, never chat history.

## Start

From the dotfiles repository:

```sh
task gascity:up
task gascity:status
task gascity:doctor
```

Run the sidecar in a second terminal:

```sh
task gascity:sidecar:serve
```

Operator UI: `http://127.0.0.1:8787/`.

## Add a repository

Prerequisites: a Git repository, `backlog.md`, and repository agent
instructions such as `AGENTS.md`.

```sh
cd ai/gascity
CITY_DIR=$PWD
RIG_DIR=/path/to/repository
RIG_NAME=my-repository
RIG_PREFIX=myrepo

mise exec -- gc --city "$CITY_DIR" rig add "$RIG_DIR" \
  --name "$RIG_NAME" \
  --prefix "$RIG_PREFIX" \
  --default-branch main \
  --include .
mise exec -- gc --city "$CITY_DIR" rig list --json
```

Use the repository's actual default branch. `rig add` changes `city.toml`;
review and commit that registration. Use `--adopt` only for an existing complete
`.beads/` store, or `--start-suspended` to delay agents.

## Preview and import one item

Run source commands from the registered repository:

```sh
cd "$RIG_DIR"
export GC_BACKLOG_SOURCE=backlog.md
export GC_BACKLOG_RELATIVE_PATH=backlog.md

"$CITY_DIR/commands/backlog-preview/run.sh"
TASK_ID=task-id-from-preview
IMPORT_JSON=$("$CITY_DIR/commands/backlog-import/run.sh" "$TASK_ID")
BEAD_ID=$(jq -r .bead_id <<<"$IMPORT_JSON")
EXTERNAL_REF=$(jq -r .external_ref <<<"$IMPORT_JSON")
```

Preview is read-only. Import is idempotent and does not change `backlog.md`.

## Dispatch

```sh
DISPATCH_JSON=$(
  jq -n \
    --arg bead "$BEAD_ID" \
    --arg ref "$EXTERNAL_REF" \
    --arg target "$RIG_NAME/import.intake" \
    '{
      bead_id: $bead,
      external_source_ref: $ref,
      target: $target,
      provider: "omp",
      max_repair_attempts: 2
    }' |
    curl --fail-with-body \
      --header 'content-type: application/json' \
      --data-binary @- \
      http://127.0.0.1:8787/workflows/dispatch
)
WORKFLOW_ID=$(jq -r .result.workflow_id <<<"$DISPATCH_JSON")
```

A `409 admission_refused` means the sidecar is paused or its budget policy
rejects new work. Dispatch never writes back to Markdown.

## Monitor

```sh
mise exec -- gc --city "$CITY_DIR" --rig "$RIG_NAME" \
  bd show "$WORKFLOW_ID" --json
mise exec -- gc --city "$CITY_DIR" --rig "$RIG_NAME" \
  session list --state all --json
curl --fail http://127.0.0.1:8787/status
```

Artifacts are under `$RIG_DIR/.gascity/work/$WORKFLOW_ID/`.

## Accept and write back

Only after the workflow root is closed with `gc.outcome=pass`:

```sh
mise exec -- gc --city "$CITY_DIR" --rig "$RIG_NAME" \
  bd close "$BEAD_ID" --reason "Workflow accepted"
"$CITY_DIR/commands/backlog-writeback/run.sh" "$TASK_ID"
```

On failure or exhausted review attempts, leave the source bead open and do not
write back.

## Repeat the backlog

Repeat preview → import → dispatch for the next actionable item. Gas City
currently automates the repair loop inside one item, not selection across the
whole backlog.

The separate direct-agent workflow can process a backlog without Gas City:

```text
/loop 10 /backlog-implement-review-loop path/to/backlog.md
```

It uses Worklease and durable provider state; it is not a Gas City dispatcher.

## Pause, resume, recover

```sh
curl --request POST --fail http://127.0.0.1:8787/control/pause
curl --request POST --fail http://127.0.0.1:8787/control/resume
```

After a restart, run `task gascity:up`, inspect the existing workflow, then
restart the sidecar. Do not redispatch merely because a session disappeared;
Beads and `.gascity/work/` are durable.

See [operations](operations.md) for cancellation and deeper recovery, and
[backlog sources](backlog-sources.md) for the Markdown grammar and adapter
details.
