#!/usr/bin/env bash
# Exercise the Markdown/Beads wrappers and the installed v2 backlog formulas.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gc11-demo.sh [happy|repair|halt|reset]

happy   import FIX-INDEPENDENT twice, run backlog-item, and write back on success
repair  import FIX-REPAIR twice, run the two-attempt repair formula, and write back
halt    import FIX-REPAIR twice, run the one-attempt formula, and expect exhaustion
reset   refresh the fixture rig and delete only beads recorded by this runner

The default mode is happy. GC11_WAIT_SECONDS and GC11_POLL_SECONDS may be set
for bounded workflow polling (defaults: 900 and 5).
EOF
}

MODE=${1:-happy}
if (($# > 1)); then
  printf 'usage: %s [happy|repair|halt|reset]\n' "$0" >&2
  exit 2
fi
if [[ $MODE == --help || $MODE == -h ]]; then
  usage
  exit 0
fi
case "$MODE" in
  happy|repair|halt|reset) ;;
  *)
    printf 'unknown mode %q\n' "$MODE" >&2
    usage >&2
    exit 2
    ;;
esac

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CITY_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
RIG_DIR="$CITY_DIR/.local/fixture-rig"
STATE_DIR="$RIG_DIR/.gc/gc11-demo"
MAKE_FIXTURE="$SCRIPT_DIR/make-fixture-rig.sh"
IMPORT_WRAPPER="$CITY_DIR/commands/backlog-import/run.sh"
WRITEBACK_WRAPPER="$CITY_DIR/commands/backlog-writeback/run.sh"
TARGET='fixture/gc.intake'
WAIT_SECONDS=${GC11_WAIT_SECONDS:-900}
POLL_SECONDS=${GC11_POLL_SECONDS:-5}

[[ $WAIT_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_WAIT_SECONDS must be a positive integer\n' >&2; exit 2; }
[[ $POLL_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_POLL_SECONDS must be a positive integer\n' >&2; exit 2; }

GC_CMD=(mise exec -- gc --city "$CITY_DIR" --rig fixture)
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/gc11-demo.XXXXXX")
cleanup() {
  if [[ -d ${TMP_DIR:-} ]]; then
    trash "$TMP_DIR" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

fail() {
  printf 'gc11-demo: %s\n' "$*" >&2
  exit 1
}

valid_bead_id() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]*$ ]]
}

append_id() {
  local file=$1 id=$2
  valid_bead_id "$id" || fail "refusing to record invalid bead ID: $id"
  printf '%s\n' "$id" >>"$file"
}

recorded_ids_present() {
  [[ -f "$STATE_DIR/imported-bead-ids" || -f "$STATE_DIR/root-bead-ids" ]]
}

delete_recorded_ids() {
  local seen=$'\n' file id members_json members member show_output
  local -a files=()
  [[ -f "$STATE_DIR/root-bead-ids" ]] && files+=("$STATE_DIR/root-bead-ids")
  [[ -f "$STATE_DIR/imported-bead-ids" ]] && files+=("$STATE_DIR/imported-bead-ids")
  ((${#files[@]})) || return 0

  for file in "${files[@]}"; do
    while IFS= read -r id || [[ -n $id ]]; do
      [[ -n $id ]] || continue
      valid_bead_id "$id" || { printf 'gc11-demo: ignoring invalid recorded ID %q\n' "$id" >&2; continue; }
      [[ $seen == *$'\n'"$id"$'\n'* ]] && continue
      seen+="$id"$'\n'
      if show_output=$("${GC_CMD[@]}" bd show "$id" --json 2>&1); then
        :
      elif [[ $show_output =~ [Nn]o[[:space:]]+issue[[:space:]]+found ]]; then
        printf 'gc11-demo: recorded bead already absent: %s\n' "$id"
        continue
      else
        fail "cannot inspect recorded bead $id; preserving demo state: $show_output"
      fi
      if [[ $file == "$STATE_DIR/root-bead-ids" ]]; then
        members_json=$("${GC_CMD[@]}" bd list --all --metadata-field "gc.root_bead_id=$id" --json --limit=0) ||
          fail "cannot enumerate workflow members for root: $id"
        members=$(jq -r --arg root "$id" '.[] | select((.metadata // {})["gc.root_bead_id"] == $root) | .id // empty' <<<"$members_json") ||
          fail "cannot parse workflow members for root: $id"
        while IFS= read -r member || [[ -n $member ]]; do
          [[ -n $member && $member != "$id" ]] || continue
          valid_bead_id "$member" || continue
          [[ $seen == *$'\n'"$member"$'\n'* ]] && continue
          seen+="$member"$'\n'
          "${GC_CMD[@]}" bd delete "$member" --force >/dev/null
          printf 'gc11-demo: deleted recorded workflow member: %s\n' "$member"
        done <<<"$members"
        "${GC_CMD[@]}" bd delete "$id" --force >/dev/null
      else
        "${GC_CMD[@]}" bd delete "$id" --force >/dev/null
      fi
      printf 'gc11-demo: deleted recorded bead: %s\n' "$id"
    done <"$file"
  done
}

reset_demo() {
  "$MAKE_FIXTURE" >/dev/null
  if ! recorded_ids_present; then
    [[ -d "$STATE_DIR" ]] && trash "$STATE_DIR"
    printf 'gc11-demo: no recorded demo beads; fixture refreshed\n'
    return 0
  fi
  delete_recorded_ids
  trash "$STATE_DIR"
  printf 'gc11-demo: reset recorded demo beads\n'
}

if [[ $MODE == reset ]]; then
  reset_demo
  exit 0
fi

# A mode starts from a fresh generated fixture and removes only a previous run's
# recorded graph, leaving any unrelated beads in the rig untouched.
if [[ -d "$STATE_DIR" ]]; then
  if recorded_ids_present; then
    delete_recorded_ids
  fi
  trash "$STATE_DIR"
fi
"$MAKE_FIXTURE" >/dev/null
mkdir -p "$STATE_DIR"
printf '%s\n' "$MODE" >"$STATE_DIR/mode"

case "$MODE" in
  happy)
    TASK_ID=fix-independent
    FORMULA=backlog-item
    ;;
  repair)
    TASK_ID=fix-repair
    FORMULA=backlog-item-repair-2
    ;;
  halt)
    TASK_ID=fix-repair
    FORMULA=backlog-item-repair-1
    ;;
esac

source_before=$(shasum -a 256 "$RIG_DIR/backlog.md")
run_import() {
  (cd "$RIG_DIR" && GC_BACKLOG_SOURCE=backlog.md "$IMPORT_WRAPPER" "$TASK_ID")
}

run_import >"$STATE_DIR/import-1.json"
first_action=$(jq -er '.action | strings' "$STATE_DIR/import-1.json")
[[ $first_action == created ]] || fail "first import did not create a demo-owned bead (action=$first_action)"
first_bead=$(jq -er '.bead_id | strings | select(length > 0)' "$STATE_DIR/import-1.json")
append_id "$STATE_DIR/imported-bead-ids" "$first_bead"
run_import >"$STATE_DIR/import-2.json"
second_action=$(jq -er '.action | strings' "$STATE_DIR/import-2.json")
[[ $second_action == skipped ]] || fail "second import did not reuse the bead (action=$second_action)"
second_bead=$(jq -er '.bead_id | strings | select(length > 0)' "$STATE_DIR/import-2.json")
append_id "$STATE_DIR/imported-bead-ids" "$second_bead"
[[ $first_bead == "$second_bead" ]] || fail "second import created a different bead ($first_bead versus $second_bead)"
source_after_import=$(shasum -a 256 "$RIG_DIR/backlog.md")
[[ $source_before == "$source_after_import" ]] || fail 'import mutated the source backlog'
printf 'gc11-demo: imported %s as %s (second import reused it)\n' "$TASK_ID" "$first_bead"

"${GC_CMD[@]}" sling "$TARGET" "$FORMULA" --formula --var "item=$first_bead" --json >"$STATE_DIR/dispatch.json"
dispatch_bead_id=$(jq -er --arg target "$TARGET" --arg formula "$FORMULA" '
  select(.success == true and .target == $target and .formula == $formula)
  | .bead_id | strings | select(length > 0)
' "$STATE_DIR/dispatch.json")
valid_bead_id "$dispatch_bead_id" || fail "dispatch returned invalid bead ID: $dispatch_bead_id"
root_id=$(jq -er --arg target "$TARGET" --arg formula "$FORMULA" '
  select(.success == true and .target == $target and .formula == $formula)
  | .workflow_id | strings | select(length > 0)
' "$STATE_DIR/dispatch.json")
printf '%s\n' "$dispatch_bead_id" >"$STATE_DIR/dispatch-bead-id"
valid_bead_id "$root_id" || fail "dispatch returned invalid workflow root: $root_id"
printf '%s\n' "$root_id" >"$STATE_DIR/root-id"
append_id "$STATE_DIR/root-bead-ids" "$root_id"
printf 'gc11-demo: dispatched %s at %s using %s\n' "$FORMULA" "$TARGET" "$root_id"

wait_for_workflow() {
  local deadline=$((SECONDS + WAIT_SECONDS)) root_json status outcome failure remaining sleep_for
  while ((SECONDS < deadline)); do
    root_json=$("${GC_CMD[@]}" bd show "$root_id" --json 2>/dev/null || true)
    if [[ -n $root_json ]]; then
      printf '%s\n' "$root_json" >"$STATE_DIR/workflow-state.json"
      status=$(jq -r 'if type == "array" then .[0].status // "" else .status // "" end' <<<"$root_json" 2>/dev/null || true)
      failure=$(jq -r 'if type == "array" then .[0].metadata["gc.failure_class"] // "" else .metadata["gc.failure_class"] // "" end' <<<"$root_json" 2>/dev/null || true)
      if [[ $failure == review_attempts_exhausted ]]; then
        return 0
      fi
      if [[ $status == closed ]]; then
        return 0
      fi
    fi
    remaining=$((deadline - SECONDS))
    ((remaining > 0)) || break
    sleep_for=$POLL_SECONDS
    ((sleep_for > remaining)) && sleep_for=$remaining
    sleep "$sleep_for"
  done
  fail "workflow root $root_id did not reach a terminal state within ${WAIT_SECONDS}s"
}
wait_for_workflow

root_json=$(cat "$STATE_DIR/workflow-state.json")
root_failure=$(jq -r 'if type == "array" then .[0].metadata["gc.failure_class"] // "" else .metadata["gc.failure_class"] // "" end' <<<"$root_json")
if [[ $MODE == halt ]]; then
  [[ $root_failure == review_attempts_exhausted ]] || fail 'halt did not record review-attempt exhaustion metadata'
  exhausted=$(jq -r 'if type == "array" then .[0].metadata["gc.exhausted_attempts"] // "" else .metadata["gc.exhausted_attempts"] // "" end' <<<"$root_json")
  [[ $exhausted == 1 ]] || fail "halt recorded exhausted attempts as ${exhausted:-<missing>}"
  printf 'gc11-demo: expected halt after %s review attempt(s); no write-back performed\n' "$exhausted"
  exit 0
fi

root_outcome=$(jq -r 'if type == "array" then .[0].metadata["gc.outcome"] // "" else .metadata["gc.outcome"] // "" end' <<<"$root_json")
[[ $root_outcome == pass ]] || fail "successful mode ended with outcome ${root_outcome:-<missing>}"
WORK_ROOT="$RIG_DIR/.gascity/work/$root_id"
for artifact in brief.md plan.md verify.md final.md; do
  [[ -s "$WORK_ROOT/$artifact" ]] || fail "missing workflow artifact: $WORK_ROOT/$artifact"
done
shopt -s nullglob
reports=("$WORK_ROOT"/attempts/*/report.md)
reviews=("$WORK_ROOT"/attempts/*/review.md)
verdicts=("$WORK_ROOT"/attempts/*/verdict.json)
shopt -u nullglob
((${#reports[@]} > 0)) || fail "no implementer reports under $WORK_ROOT/attempts"
((${#reviews[@]} == ${#reports[@]})) || fail 'not every implementer report has a review report'
((${#verdicts[@]} == ${#reports[@]})) || fail 'not every implementer report has a verdict'
if [[ $MODE == repair ]]; then
  ((${#reports[@]} >= 2)) || fail 'repair workflow did not produce at least two implementer reports'
  [[ -s "$WORK_ROOT/attempts/1/report.md" && -s "$WORK_ROOT/attempts/2/report.md" ]] || fail 'repair workflow is missing attempts 1 or 2 report'
  [[ -s "$WORK_ROOT/attempts/1/review.md" && -s "$WORK_ROOT/attempts/2/review.md" ]] || fail 'repair workflow is missing attempts 1 or 2 review'
  [[ -s "$WORK_ROOT/attempts/1/verdict.json" && -s "$WORK_ROOT/attempts/2/verdict.json" ]] || fail 'repair workflow is missing attempts 1 or 2 verdict'
  jq -e '.attempt == 1 and .verdict == "fail"' "$WORK_ROOT/attempts/1/verdict.json" >/dev/null || fail 'repair attempt 1 did not record the intentional failure'
  jq -e '.attempt == 2 and .verdict == "pass"' "$WORK_ROOT/attempts/2/verdict.json" >/dev/null || fail 'repair attempt 2 did not pass'
fi
for artifact in "${reports[@]}" "${reviews[@]}" "${verdicts[@]}"; do
  [[ -s "$artifact" ]] || fail "empty workflow artifact: $artifact"
done
printf 'gc11-demo: verified durable workflow artifacts under %s\n' "$WORK_ROOT"

"${GC_CMD[@]}" bd close "$first_bead" --reason 'GC-11 demo workflow completed; explicit write-back follows' >/dev/null
(cd "$RIG_DIR" && GC_BACKLOG_SOURCE=backlog.md "$WRITEBACK_WRAPPER" "$TASK_ID") >"$STATE_DIR/writeback.json"
jq -e --arg bead "$first_bead" '.action == "marked_done" and .bead_id == $bead' "$STATE_DIR/writeback.json" >/dev/null || fail 'explicit write-back did not mark the imported bead done'
source_after_writeback=$(shasum -a 256 "$RIG_DIR/backlog.md")
[[ $source_before != "$source_after_writeback" ]] || fail 'explicit write-back did not change the source backlog'

if ! "${GC_CMD[@]}" doctor --json >"$STATE_DIR/doctor.json"; then
  fail 'gc doctor --json failed'
fi
jq -e '(.failed == 0) and (.blocking_failed == 0)' "$STATE_DIR/doctor.json" >/dev/null || fail 'gc doctor --json was not clean'
printf 'gc11-demo: %s workflow and explicit write-back passed; doctor clean\n' "$MODE"
