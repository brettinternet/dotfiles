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

Run every repeat from the repository root with reset first. Reset regenerates
the fixture rig's tracked files and removes only graphs recorded by prior
GC-11 runs; it deliberately preserves unrelated GC-07 roots:

```sh
task gascity:demo:reset
```
The controller must be healthy and supervisor-managed before dispatch. Each
public demo (`demo`, `demo:repair`, and `demo:halt`) prepares one durable,
nonterminal session record for each exact phase template
(`fixture/gc.intake`, `fixture/gc.planner`, `fixture/gc.implementer`,
`fixture/gc.verifier`, and `fixture/gc.reviewer`), reusing a matching record
or creating a detached session. It reloads the supervisor, wakes the selected
session identities, and reloads again. With `max_active_sessions = 2`, runtime
capacity remains bounded; durable records do not mean that five workers run at
once.
The `GC11_PREWARM_SECONDS` setting controls a bounded gate (default 60 seconds)
that waits only for a healthy, running controller. It does not wait for intake
or any phase session to become active. Once the controller is healthy and
running, the formula is slung immediately with `--nudge`; actual phase runtime
startup is current-root demand-driven as workflow polling finds ready work.
Do not manually assign phases, nudge each phase, or recover duplicate workflow
roots as part of the normal demo.
Prewarm handles the bounded discovery-to-wake race: if a selected reusable
session closes or is not found between discovery and wake, it creates one fresh
detached session for that exact template, replaces the selected ID, wakes the
replacement, and continues to dispatch. This is same-template race recovery,
not generic retry behavior; any other wake failure remains fatal.

After dispatch, bounded workflow polling asks each phase hook for ready work and
filters its results to entries whose `gc.root_bead_id` matches the current
workflow `root_id`. Assigned or in-progress work is excluded by hook readiness,
so unrelated roots never control phase selection or trigger resets.
For the first workflow-order phase with an unassigned ready bead, polling
selects that phase's durable session identity. During demand-time orchestration,
if that selected session has since closed or is not found, it creates one fresh
same-template replacement, updates the selected ID, wakes the replacement, and
performs the supervisor reconciliation. Otherwise, if the selected session is
stale or has no process, it resets and wakes that same selected identity, then
performs one supervisor reconciliation (a batched reload). Each selected phase
session ID receives at most one reset+wake request; later polls with that same
ID wait for the requested startup. If a closed or not-found ID is replaced,
the replacement is woken once and is considered already wake-requested, so a
newly selected ID can receive its own single request. No bead is manually
assigned or closed, and recovery is not a manual step.
The workflow deadline is bounded by `GC11_WAIT_SECONDS`, which defaults to 3600
seconds to cover five fresh provider phases plus review and repair. This
deadline is distinct from the 60-second `GC11_PREWARM_SECONDS` gate.

From the repository root, these task names invoke
`ai/gascity/assets/scripts/gc11-demo.sh` with the matching mode:
`gascity:demo` → `happy`, `gascity:demo:repair` → `repair`,
`gascity:demo:halt` → `halt`, and `gascity:demo:reset` → `reset`.

The public happy-path task runs the complete import → dispatch →
post-dispatch idempotency assertion → workflow → explicit write-back sequence:

```sh
task gascity:demo
```

To run that sequence manually, first ensure the supervisor-managed controller is
healthy and prepare durable nonterminal records for all five exact phase
templates before importing or dispatching. The public task performs the
discovery, wake/reload, and bounded controller-health gate automatically; it
does not wait for intake or phase sessions to become active. Once the gate
passes, sling immediately. The concise manual equivalent is:

```sh
cd ai/gascity
CITY_DIR=$PWD
GC=(mise exec -- gc --city "$CITY_DIR" --rig fixture)
"${GC[@]}" doctor
PHASE_TEMPLATES=(
  fixture/gc.intake fixture/gc.planner fixture/gc.implementer
  fixture/gc.verifier fixture/gc.reviewer
)
PHASE_IDS=()
for template in "${PHASE_TEMPLATES[@]}"; do
  id="$("${GC[@]}" session list --state all --json |
    jq -r --arg template "$template" '
      [.sessions[] |
       select(.template == $template and (.closed // false) != true
         and .state != "closed")] |
      .[0].id // empty')"
  if [[ -z "$id" ]]; then
    id="$("${GC[@]}" session new "$template" --no-attach --json |
      jq -er '.session_id // .id // empty')"
  fi
  PHASE_IDS+=("$id")
done
"${GC[@]}" supervisor reload
for id in "${PHASE_IDS[@]}"; do
  "${GC[@]}" session wake "$id" --json
done
"${GC[@]}" supervisor reload
HEALTHY=false
for _ in $(seq 1 "${GC11_PREWARM_SECONDS:-60}"); do
  if "${GC[@]}" status --json 2>/dev/null |
    jq -e '
      (.running == true or .controller.running == true
       or .status == "running" or .controller.status == "running")
      and
      (.health.usable == true or .controller.health.usable == true)
    ' >/dev/null; then
    HEALTHY=true
    break
  fi
  sleep 1
done
test "$HEALTHY" = true
RIG_DIR=$CITY_DIR/.local/fixture-rig
IMPORT=$CITY_DIR/commands/backlog-import/run.sh
WRITEBACK=$CITY_DIR/commands/backlog-writeback/run.sh
cd "$RIG_DIR"
```

Then import the actionable Markdown task, dispatch the returned bead to the
intake target, repeat the import after dispatch and verify it returns the same
bead, wait for an accepted/closed workflow, then write back explicitly:

```sh
BEAD_ID="$(GC_BACKLOG_SOURCE=backlog.md "$IMPORT" fix-independent | jq -er '.bead_id')"
WORKFLOW_ID="$(
  mise exec -- gc --city "$CITY_DIR" --rig fixture sling fixture/gc.intake \
    backlog-item --formula --nudge --var item="$BEAD_ID" \
    --var max_repair_attempts=2 --json | jq -er '.workflow_id'
)"
POST_DISPATCH_BEAD_ID="$(
  GC_BACKLOG_SOURCE=backlog.md "$IMPORT" fix-independent |
    jq -er --arg bead "$BEAD_ID" '
      select(.action == "skipped" and .bead_id == $bead) | .bead_id'
)"
test "$POST_DISPATCH_BEAD_ID" = "$BEAD_ID"
bd search - --external-contains 'md:backlog.md#fix-independent' \
  --status all --limit 0 --json |
  jq -er '[.[] | select(.external_ref == "md:backlog.md#fix-independent")] |
    if length == 1 then .[0].id else error("expected exactly one bead") end'
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
`fixture`. Successful paths close the imported source bead before
`backlog-writeback`; they retain `brief.md`, `plan.md`, `verify.md`, `final.md`,
and every attempt's report, review, and verdict under
`.gascity/work/<root>/`. The expected halt closes with
`gc.failure_class=review_attempts_exhausted` and
`gc.exhausted_attempts=1`; it retains only `brief.md`, `plan.md`, and exactly
one failed attempt's report, review, and verdict, leaves the source bead open,
and does not write back. It does not produce `verify.md` or `final.md`. The
max-one-live exhaustion evidence is an expected halt/demo dependency boundary,
not a claim that GC-07 is complete.

Finish every run with the doctor gate:

```sh
cd ai/gascity
mise exec -- gc doctor
```
