# Gas City

This directory is the portable city configuration and pack. Runtime state,
beads, and machine-local overrides remain ignored (`.gc/`, `.beads/`,
`city.local.toml`, and `.env`).

## Initialize

The city was initialized with:

```sh
mise exec -- gc init --template gascity --default-provider codex \
  --skip-provider-readiness --yes --preserve-existing ai/gascity
```

`gc init` registers and starts the city under the machine-wide launchd
supervisor `com.gascity.supervisor`. Use the namespaced Taskfile commands from
the repository root:

```sh
task gascity:doctor
task gascity:status
task gascity:up
task gascity:down
```

## GC-11 demo: Markdown → Beads → workflow → outcome

Run every repeat from the repository root with reset first. Reset clears only
demo-recorded roots and imported fixture beads; the fixture refresh regenerates
the ignored rig files:

```sh
task gascity:demo:reset
cd ai/gascity
./assets/scripts/make-fixture-rig.sh
```

From the repository root, these task names invoke
`ai/gascity/assets/scripts/gc11-demo.sh` with the matching mode:
`gascity:demo` → `happy`, `gascity:demo:repair` → `repair`,
`gascity:demo:halt` → `halt`, and `gascity:demo:reset` → `reset`.

The public happy-path task runs the complete import → workflow → explicit
write-back sequence:

```sh
task gascity:demo
```

To run that sequence manually, import the actionable Markdown task, repeat the
same import, dispatch the returned bead to the intake target, wait for an
accepted/closed workflow, then write back explicitly:

```sh
cd ai/gascity
CITY_DIR=$PWD
RIG_DIR=$CITY_DIR/.local/fixture-rig
IMPORT=$CITY_DIR/commands/backlog-import/run.sh
WRITEBACK=$CITY_DIR/commands/backlog-writeback/run.sh
cd "$RIG_DIR"
BEAD_ID="$(GC_BACKLOG_SOURCE=backlog.md "$IMPORT" fix-independent | jq -er '.bead_id')"
GC_BACKLOG_SOURCE=backlog.md "$IMPORT" fix-independent
bd search - --external-contains 'md:backlog.md#fix-independent' \
  --status all --limit 0 --json |
  jq -er '[.[] | select(.external_ref == "md:backlog.md#fix-independent")] |
    if length == 1 then .[0].id else error("expected exactly one bead") end'
WORKFLOW_ID="$(
  mise exec -- gc --city "$CITY_DIR" --rig fixture sling fixture/gc.intake \
    backlog-item --formula --var item="$BEAD_ID" \
    --var max_repair_attempts=2 --json | jq -er '.workflow_id'
)"
for _ in $(seq 1 120); do
  SHOW_JSON="$(mise exec -- gc --city "$CITY_DIR" --rig fixture \
    bd show "$WORKFLOW_ID" --json)"
  STATUS="$(jq -er 'if type == "array" then .[0] else . end | .status // ""' \
    <<<"$SHOW_JSON")"
  FAILURE_CLASS="$(jq -r \
    'if type == "array" then .[0] else . end | .metadata["gc.failure_class"] // ""' \
    <<<"$SHOW_JSON")"
  [[ $STATUS == closed ]] && break
  [[ $FAILURE_CLASS == review_attempts_exhausted ]] && {
    echo "GC-11 workflow halted after the retry limit" >&2
    exit 1
  }
  sleep 1
done
test "${STATUS:-}" = closed
WORK_ROOT=".gascity/work/$WORKFLOW_ID"
for name in brief.md plan.md verify.md final.md; do test -f "$WORK_ROOT/$name"; done
for name in "$WORK_ROOT"/attempts/*/report.md \
  "$WORK_ROOT"/attempts/*/review.md "$WORK_ROOT"/attempts/*/verdict.json; do
  test -f "$name"
done
mise exec -- gc --city "$CITY_DIR" --rig fixture \
  bd show "$WORKFLOW_ID" --json |
  jq -e 'if type == "array" then .[0] else . end |
    if .status == "closed" and .metadata["gc.outcome"] == "pass"
    then true
    else error("workflow root must be closed with gc.outcome=pass")
    end' >/dev/null
mise exec -- gc --city "$CITY_DIR" --rig fixture bd close "$BEAD_ID" \
  --reason "GC-11 demo completed"
GC_BACKLOG_SOURCE=backlog.md "$WRITEBACK" fix-independent
```

Use the reset-first variants for the bounded failure paths:

```sh
task gascity:demo:reset
task gascity:demo:repair
# imports fix-repair; backlog-item-repair-2 fails once, repairs, and writes back

task gascity:demo:reset
task gascity:demo:halt
# imports fix-repair; backlog-item-repair-1 exhausts its limit and halts
```

All dispatches use the supported `fixture/gc.intake` target, never bare
`fixture`. A successful path closes the imported source bead before
`backlog-writeback`; the expected halt leaves that source bead open and does
not write back. The max-one-live exhaustion evidence is an expected
halt/demo dependency boundary, not a claim that GC-07 is complete.

Intermediate and final reports remain durable after sessions exit under
`.gascity/work/<root>/`: `brief.md`, `plan.md`, `verify.md`, `final.md`, and
each `attempts/<n>/` report, review, and verdict.
Finish every run with the doctor gate:

```sh
cd ai/gascity
mise exec -- gc doctor
```
