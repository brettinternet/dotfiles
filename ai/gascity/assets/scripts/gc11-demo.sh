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

The default mode is happy. GC11_PREWARM_SECONDS, GC11_WAIT_SECONDS, and
GC11_POLL_SECONDS may be set for bounded preflight/workflow polling
(defaults: 60, 3600, and 5).
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
WAIT_SECONDS=${GC11_WAIT_SECONDS:-3600}
PREWARM_SECONDS=${GC11_PREWARM_SECONDS:-60}
POLL_SECONDS=${GC11_POLL_SECONDS:-5}

[[ $WAIT_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_WAIT_SECONDS must be a positive integer\n' >&2; exit 2; }
[[ $PREWARM_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_PREWARM_SECONDS must be a positive integer\n' >&2; exit 2; }
[[ $POLL_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_POLL_SECONDS must be a positive integer\n' >&2; exit 2; }
PHASE_TEMPLATES=(
  fixture/gc.intake
  fixture/gc.planner
  fixture/gc.implementer
  fixture/gc.verifier
  fixture/gc.reviewer
)
PHASE_SESSION_IDS=()
PHASE_RESET_SESSION_IDS=("" "" "" "" "")


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

prepare_phase_sessions() {
  local session_json new_json session_id template controller_json
  local controller_status controller_health all_ready
  local deadline remaining sleep_for
  local i wake_status wake_err wake_diag
  local replacement_json replacement_id replacement_status replacement_err replacement_diag
  local replacement_parse_status replacement_parse_err replacement_parse_diag
  local replacement_wake_status replacement_wake_err replacement_wake_diag
  PHASE_SESSION_IDS=()

  session_json=$("${GC_CMD[@]}" session list --state all --json) ||
    fail 'cannot list phase sessions before formula sling'
  for template in "${PHASE_TEMPLATES[@]}"; do
    session_id=$(jq -r --arg template "$template" '
      (.sessions // [])
      | map(select(
          ((.template // .template_name // "") == $template)
          and ((.closed // false) != true)
          and ((.state // "") != "closed")
        ))
      | sort_by(.id // .session_id // "")
      | .[0].id // .[0].session_id // empty
    ' <<<"$session_json") || fail "cannot parse session list for $template"
    if [[ -z $session_id ]]; then
      new_json=$("${GC_CMD[@]}" session new "$template" --no-attach --json) ||
        fail "cannot create phase session for $template"
      session_id=$(jq -er '.session_id // .id // empty' <<<"$new_json") ||
        fail "session new returned no session_id for $template"
    fi
    PHASE_SESSION_IDS+=("$session_id")
  done

  "${GC_CMD[@]}" supervisor reload >/dev/null ||
    fail 'cannot reload supervisor after preparing phase sessions'
  for i in "${!PHASE_SESSION_IDS[@]}"; do
    template=${PHASE_TEMPLATES[$i]}
    session_id=${PHASE_SESSION_IDS[$i]}
    wake_err="$TMP_DIR/phase-wake-${i}.err"
    if "${GC_CMD[@]}" session wake "$session_id" --json >/dev/null 2>"$wake_err"; then
      continue
    else
      wake_status=$?
    fi
    [[ -s $wake_err ]] && wake_diag=$(tr '\n' ' ' <"$wake_err")
    if [[ $wake_diag == *"$session_id"* ]] &&
       [[ $wake_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
      replacement_err="$TMP_DIR/phase-new-${i}.err"
      replacement_json=
      if replacement_json=$("${GC_CMD[@]}" session new "$template" --no-attach --json 2>"$replacement_err"); then
        replacement_status=0
      else
        replacement_status=$?
        replacement_diag=
        [[ -s $replacement_err ]] && replacement_diag=$(tr '\n' ' ' <"$replacement_err")
        fail "cannot replace closed phase session template=$template old=$session_id new=<none> create_exit=$replacement_status${replacement_diag:+; stderr=$replacement_diag}"
      fi
      replacement_parse_err="$TMP_DIR/phase-new-parse-${i}.err"
      if replacement_id=$(jq -er -s '
        if length != 1 or (.[0] | type) != "object" then
          error("session new result is not one object")
        elif (.[0].session_id | type) == "string" and (.[0].session_id | test("^[^[:space:]]+$")) then
          .[0].session_id
        elif .[0].session_id == null and (.[0].id | type) == "string" and (.[0].id | test("^[^[:space:]]+$")) then
          .[0].id
        else
          error("session new result has no strict session ID")
        end
      ' <<<"$replacement_json" 2>"$replacement_parse_err"); then
        replacement_parse_status=0
      else
        replacement_parse_status=$?
        replacement_parse_diag=
        [[ -s $replacement_parse_err ]] && replacement_parse_diag=$(tr '\n' ' ' <"$replacement_parse_err")
        fail "cannot parse replacement phase session template=$template old=$session_id new=<invalid> parse_exit=$replacement_parse_status${replacement_parse_diag:+; stderr=$replacement_parse_diag}"
      fi
      PHASE_SESSION_IDS[i]=$replacement_id
      replacement_wake_err="$TMP_DIR/phase-wake-replacement-${i}.err"
      if "${GC_CMD[@]}" session wake "$replacement_id" --json >/dev/null 2>"$replacement_wake_err"; then
        continue
      else
        replacement_wake_status=$?
      fi
      [[ -s $replacement_wake_err ]] &&
        replacement_wake_diag=$(tr '\n' ' ' <"$replacement_wake_err")
      fail "cannot wake replacement phase session template=$template old=$session_id new=$replacement_id wake_exit=$replacement_wake_status${replacement_wake_diag:+; stderr=$replacement_wake_diag}"
    fi
    fail "cannot wake phase session template=$template old=$session_id new=$session_id wake_exit=$wake_status${wake_diag:+; stderr=$wake_diag}"
  done
  "${GC_CMD[@]}" supervisor reload >/dev/null ||
    fail 'cannot reload supervisor after waking phase sessions'

  deadline=$((SECONDS + PREWARM_SECONDS))
  while ((SECONDS < deadline)); do
    controller_json=$("${GC_CMD[@]}" status --json 2>/dev/null || true)
    controller_status=missing
    controller_health=missing
    if [[ -n $controller_json ]]; then
      controller_status=$(jq -r '
        if (.running == true or .controller.running == true or
            .status == "running" or .controller.status == "running") then
          "running"
        elif (.running == false or .controller.running == false or
              .status == "stopped" or .controller.status == "stopped") then
          "stopped"
        else
          "missing"
        end
      ' <<<"$controller_json" 2>/dev/null) || controller_status=missing
      controller_health=$(jq -r '
        if (.health.usable == true or .controller.health.usable == true) then
          "usable"
        elif (.health.usable == false or .controller.health.usable == false) then
          "unusable"
        else
          "missing"
        end
      ' <<<"$controller_json" 2>/dev/null) || controller_health=missing
    fi
    all_ready=$([[ $controller_status == running && $controller_health == usable ]] && printf true || printf false)
    [[ $all_ready == true ]] && return 0
    remaining=$((deadline - SECONDS))
    ((remaining > 0)) || break
    sleep_for=$POLL_SECONDS
    ((sleep_for > remaining)) && sleep_for=$remaining
    sleep "$sleep_for"
  done

  fail "controller prewarm failed after ${PREWARM_SECONDS}s; controller/status=${controller_status:-missing},health=${controller_health:-missing}"
}

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

prepare_phase_sessions

"${GC_CMD[@]}" sling "$TARGET" "$FORMULA" --formula --var "item=$first_bead" --nudge --json >"$STATE_DIR/dispatch.json"
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
run_import >"$STATE_DIR/import-3.json"
third_action=$(jq -er '.action | strings' "$STATE_DIR/import-3.json")
[[ $third_action == skipped ]] || fail "mid-flow import did not reuse the bead (action=$third_action)"
third_bead=$(jq -er '.bead_id | strings | select(length > 0)' "$STATE_DIR/import-3.json")
[[ $first_bead == "$third_bead" ]] || fail "mid-flow import created a different bead ($first_bead versus $third_bead)"
source_after_midflow_import=$(shasum -a 256 "$RIG_DIR/backlog.md")
[[ $source_after_import == "$source_after_midflow_import" ]] || fail 'mid-flow import mutated the source backlog'
printf 'gc11-demo: dispatched %s at %s using %s; mid-flow import reused it\n' "$FORMULA" "$TARGET" "$root_id"

replace_ready_phase_session() {
  local i=$1 template=$2 old_session_id=$3
  local replacement_json replacement_id replacement_status replacement_err replacement_diag
  local replacement_parse_status replacement_parse_err replacement_parse_diag
  local replacement_wake_status replacement_wake_err replacement_wake_diag
  replacement_err="$TMP_DIR/demand-replacement-new-${i}.err"
  replacement_json=
  if replacement_json=$("${GC_CMD[@]}" session new "$template" --no-attach --json 2>"$replacement_err"); then
    replacement_status=0
  else
    replacement_status=$?
    replacement_diag=
    [[ -s $replacement_err ]] && replacement_diag=$(tr '\n' ' ' <"$replacement_err")
    fail "phase-demand replacement failure: cannot create replacement session (root=$root_id template=$template old=$old_session_id create_exit=$replacement_status${replacement_diag:+; stderr=$replacement_diag})"
  fi
  replacement_parse_err="$TMP_DIR/demand-replacement-parse-${i}.err"
  if replacement_id=$(jq -er -s '
    if length != 1 or (.[0] | type) != "object" then
      error("session new result is not one object")
    elif (.[0].session_id | type) == "string" and (.[0].session_id | test("^[^[:space:]]+$")) then
      .[0].session_id
    elif .[0].session_id == null and (.[0].id | type) == "string" and (.[0].id | test("^[^[:space:]]+$")) then
      .[0].id
    else
      error("session new result has no strict session ID")
    end
  ' <<<"$replacement_json" 2>"$replacement_parse_err"); then
    replacement_parse_status=0
  else
    replacement_parse_status=$?
    replacement_parse_diag=
    [[ -s $replacement_parse_err ]] && replacement_parse_diag=$(tr '\n' ' ' <"$replacement_parse_err")
    fail "phase-demand replacement failure: cannot parse replacement session (root=$root_id template=$template old=$old_session_id new=<invalid> parse_exit=$replacement_parse_status${replacement_parse_diag:+; stderr=$replacement_parse_diag})"
  fi
  PHASE_SESSION_IDS[i]=$replacement_id
  replacement_wake_err="$TMP_DIR/demand-replacement-wake-${i}.err"
  if "${GC_CMD[@]}" session wake "$replacement_id" --json >/dev/null 2>"$replacement_wake_err"; then
    :
  else
    replacement_wake_status=$?
    replacement_wake_diag=
    [[ -s $replacement_wake_err ]] && replacement_wake_diag=$(tr '\n' ' ' <"$replacement_wake_err")
    fail "phase-demand replacement failure: cannot wake replacement session (root=$root_id template=$template old=$old_session_id new=$replacement_id wake_exit=$replacement_wake_status${replacement_wake_diag:+; stderr=$replacement_wake_diag})"
  fi
  PHASE_RESET_SESSION_IDS[i]=$replacement_id
}

session_state_for_reset() {
  local i=$1 template=$2 session_id=$3
  local session_json session_status session_err session_diag

  session_err="$TMP_DIR/demand-session-list-${i}.err"
  session_json=
  if session_json=$("${GC_CMD[@]}" session list --state all --json 2>"$session_err"); then
    session_status=0
  else
    session_status=$?
  fi
  session_diag=
  [[ -s $session_err ]] && session_diag=$(tr '\n' ' ' <"$session_err")
  if ((session_status != 0)); then
    fail "cannot list exact reset session (root=$root_id template=$template session=$session_id exit=$session_status${session_diag:+; stderr=$session_diag})"
  fi
  jq -er --arg template "$template" --arg session_id "$session_id" '
    if type != "object" or (.sessions | type) != "array" then
      error("session list result is not an object with sessions")
    else
      [.sessions[] | select((.id // .session_id // "") == $session_id)] as $by_id
      | if ($by_id | length) == 0 then
          "missing"
        elif ($by_id | length) != 1 then
          error("session ID is not unique")
        elif (($by_id[0].template // $by_id[0].template_name // "") | type) != "string"
          or (($by_id[0].state // "") | type) != "string" then
          error("matching session has malformed template/state")
        elif ($by_id[0].template // $by_id[0].template_name // "") != $template then
          "mismatch"
        elif (($by_id[0].closed // false) == true) or (($by_id[0].state // "") == "closed") then
          "closed"
        else
          "present"
        end
    end
  ' <<<"$session_json" ||
    fail "cannot parse exact reset session (root=$root_id template=$template session=$session_id)"
}
wake_ready_phase_sessions() {
  local i template session_id hook_json hook_status hook_err hook_diag matching_ready
  local status_json status_status status_err status_diag agent_running
  local reset_status reset_err reset_diag wake_status wake_err wake_diag session_state
  local -a reset_templates=()

  for i in "${!PHASE_TEMPLATES[@]}"; do
    template=${PHASE_TEMPLATES[$i]}
    session_id=${PHASE_SESSION_IDS[$i]}
    hook_err="$TMP_DIR/hook-${i}.err"
    hook_json=
    if hook_json=$(cd "$RIG_DIR" && "${GC_CMD[@]}" hook "$template" --json 2>"$hook_err"); then
      hook_status=0
    else
      hook_status=$?
    fi
    hook_diag=
    [[ -s $hook_err ]] && hook_diag=$(tr '\n' ' ' <"$hook_err")

    if [[ -z ${hook_json//[[:space:]]/} ]]; then
      if ((hook_status != 0 && hook_status != 1)); then
        fail "hook $template failed with exit $hook_status (session=$session_id${hook_diag:+; stderr=$hook_diag})"
      fi
      continue
    fi
    if ! jq -e -s 'length == 1 and (.[0] | type == "array")' >/dev/null 2>&1 <<<"$hook_json"; then
      fail "hook $template returned malformed/non-array JSON (session=$session_id)"
    fi
    if ((hook_status == 1)); then
      continue
    fi
    if ((hook_status != 0)); then
      fail "hook $template failed with exit $hook_status (session=$session_id${hook_diag:+; stderr=$hook_diag})"
    fi
    matching_ready=$(jq -er --arg root "$root_id" '
      [.[] | select((.metadata // {})["gc.root_bead_id"] == $root)] | length
    ' <<<"$hook_json") || fail "cannot scope hook $template to root $root_id (session=$session_id)"
    if ((matching_ready > 0)); then
      status_err="$TMP_DIR/status-${i}.err"
      status_json=
      if status_json=$("${GC_CMD[@]}" status --json 2>"$status_err"); then
        status_status=0
      else
        status_status=$?
      fi
      status_diag=
      [[ -s $status_err ]] && status_diag=$(tr '\n' ' ' <"$status_err")
      if ((status_status != 0)); then
        fail "status --json failed (root=$root_id template=$template session=$session_id exit=$status_status${status_diag:+; stderr=$status_diag})"
      fi
      if [[ -z ${status_json//[[:space:]]/} ]] || ! jq -e -s '
        length == 1
        and (.[0] | type == "object"
          and (.agents | type == "array")
          and all(.agents[]; type == "object"
            and (.qualified_name | type == "string")
            and (.running | type == "boolean")))
      ' >/dev/null 2>&1 <<<"$status_json"; then
        fail "status --json returned malformed JSON (root=$root_id template=$template session=$session_id)"
      fi
      agent_running=$(jq -r --arg template "$template" '
        any(.agents[]; .qualified_name == $template and .running == true)
      ' <<<"$status_json") ||
        fail "cannot inspect status agents (root=$root_id template=$template session=$session_id)"
      if [[ $agent_running == true ]]; then
        break
      fi
      if [[ ${PHASE_RESET_SESSION_IDS[i]} == "$session_id" ]]; then
        session_state=$(session_state_for_reset "$i" "$template" "$session_id")
        case "$session_state" in
          present)
            break
            ;;
          missing|closed)
            replace_ready_phase_session "$i" "$template" "$session_id"
            reset_templates+=("$template")
            break
            ;;
          *)
            fail "cannot inspect exact reset session (root=$root_id template=$template session=$session_id state=$session_state)"
            ;;
        esac
      fi
      reset_err="$TMP_DIR/reset-${i}.err"
      if "${GC_CMD[@]}" session reset "$session_id" --json >/dev/null 2>"$reset_err"; then
        :
      else
        reset_status=$?
        reset_diag=
        [[ -s $reset_err ]] && reset_diag=$(tr '\n' ' ' <"$reset_err")
        if [[ $reset_diag == *"$session_id"* ]] &&
           [[ $reset_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
          replace_ready_phase_session "$i" "$template" "$session_id"
          reset_templates+=("$template")
          break
        fi
        fail "cannot reset ready session (root=$root_id template=$template session=$session_id exit=$reset_status${reset_diag:+; stderr=$reset_diag})"
      fi
      wake_err="$TMP_DIR/wake-${i}.err"
      if "${GC_CMD[@]}" session wake "$session_id" --json >/dev/null 2>"$wake_err"; then
        :
      else
        wake_status=$?
        wake_diag=
        [[ -s $wake_err ]] && wake_diag=$(tr '\n' ' ' <"$wake_err")
        if [[ $wake_diag == *"$session_id"* ]] &&
           [[ $wake_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
          replace_ready_phase_session "$i" "$template" "$session_id"
          reset_templates+=("$template")
          break
        fi
        fail "cannot wake reset session (root=$root_id template=$template session=$session_id exit=$wake_status${wake_diag:+; stderr=$wake_diag})"
      fi
      PHASE_RESET_SESSION_IDS[i]=$session_id
      reset_templates+=("$template")
      break
    fi
  done

  if ((${#reset_templates[@]} > 0)); then
    if ! "${GC_CMD[@]}" supervisor reload >/dev/null; then
      fail "cannot reload supervisor after resetting ready templates: ${reset_templates[*]}"
    fi
  fi
}

wait_for_workflow() {
  local deadline=$((SECONDS + WAIT_SECONDS)) root_json status remaining sleep_for
  while ((SECONDS < deadline)); do
    wake_ready_phase_sessions
    root_json=$("${GC_CMD[@]}" bd show "$root_id" --json 2>/dev/null || true)
    if [[ -n $root_json ]]; then
      printf '%s\n' "$root_json" >"$STATE_DIR/workflow-state.json"
      status=$(jq -r 'if type == "array" then .[0].status // "" else .status // "" end' <<<"$root_json" 2>/dev/null || true)
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

wait_for_phase_sessions_closed() {
  local deadline=$((SECONDS + WAIT_SECONDS))
  local i template session_id session_state pending
  local remaining sleep_for

  while ((SECONDS < deadline)); do
    pending=
    for i in "${!PHASE_TEMPLATES[@]}"; do
      template=${PHASE_TEMPLATES[$i]}
      session_id=${PHASE_SESSION_IDS[$i]-}
      [[ -n $session_id ]] ||
        fail "final phase session ID is missing (root=$root_id template=$template session=<missing>)"
      session_state=$(session_state_for_reset "$i" "$template" "$session_id")
      case "$session_state" in
        missing|closed)
          ;;
        present)
          pending+="${pending:+; }template=$template session=$session_id"
          ;;
        *)
          fail "cannot inspect final phase session (root=$root_id template=$template session=$session_id state=$session_state)"
          ;;
      esac
    done
    [[ -z $pending ]] && return 0
    remaining=$((deadline - SECONDS))
    ((remaining > 0)) || break
    sleep_for=$POLL_SECONDS
    ((sleep_for > remaining)) && sleep_for=$remaining
    sleep "$sleep_for"
  done
  fail "phase sessions did not become missing or closed within ${WAIT_SECONDS}s (root=$root_id $pending)"
}

require_attempt_artifacts() {
  local attempt_path attempt_name artifact
  local -a attempts=()
  shopt -s nullglob
  attempts=("$WORK_ROOT"/attempts/*)
  shopt -u nullglob
  ((${#attempts[@]} > 0)) || fail "no implementer attempts under $WORK_ROOT/attempts"
  if [[ $MODE == halt ]]; then
    ((${#attempts[@]} == 1)) || fail "halt produced ${#attempts[@]} attempts instead of exactly one"
    [[ -d "$WORK_ROOT/attempts/1" ]] || fail 'halt attempt is not attempts/1'
    [[ ! -e "$WORK_ROOT/attempts/2" ]] || fail 'halt unexpectedly produced attempt 2'
  elif [[ $MODE == repair ]]; then
    ((${#attempts[@]} >= 2)) || fail 'repair workflow did not produce at least two implementer attempts'
  fi
  for attempt_path in "${attempts[@]}"; do
    [[ -d "$attempt_path" ]] || fail "workflow attempt is not a directory: $attempt_path"
    attempt_name=${attempt_path##*/}
    [[ $attempt_name =~ ^[1-9][0-9]*$ ]] || fail "workflow attempt has invalid name: $attempt_name"
    for artifact in report.md review.md verdict.json; do
      [[ -s "$attempt_path/$artifact" ]] || fail "missing or empty workflow artifact: $attempt_path/$artifact"
    done
  done
}

require_clean_doctor() {
  if ! "${GC_CMD[@]}" doctor --json >"$STATE_DIR/doctor.json"; then
    fail 'gc doctor --json failed'
  fi
  jq -e '(.failed == 0) and (.blocking_failed == 0)' "$STATE_DIR/doctor.json" >/dev/null ||
    fail 'gc doctor --json was not clean'
}
wait_for_workflow

root_json=$(cat "$STATE_DIR/workflow-state.json")
root_status=$(jq -r 'if type == "array" then .[0].status // "" else .status // "" end' <<<"$root_json")
[[ $root_status == closed ]] || fail "workflow root did not close (status=${root_status:-<missing>})"
wait_for_phase_sessions_closed
root_failure=$(jq -r 'if type == "array" then .[0].metadata["gc.failure_class"] // "" else .metadata["gc.failure_class"] // "" end' <<<"$root_json")
WORK_ROOT="$RIG_DIR/.gascity/work/$root_id"
if [[ $MODE == halt ]]; then
  for artifact in brief.md plan.md; do
    [[ -s "$WORK_ROOT/$artifact" ]] || fail "missing workflow artifact: $WORK_ROOT/$artifact"
  done
  require_attempt_artifacts
  jq -e '.attempt == 1 and .verdict == "fail"' "$WORK_ROOT/attempts/1/verdict.json" >/dev/null ||
    fail 'halt attempt 1 did not record the expected failure verdict'
  [[ $root_failure == review_attempts_exhausted ]] || fail 'halt did not record review-attempt exhaustion metadata'
  exhausted=$(jq -r 'if type == "array" then .[0].metadata["gc.exhausted_attempts"] // "" else .metadata["gc.exhausted_attempts"] // "" end' <<<"$root_json")
  [[ $exhausted == 1 ]] || fail "halt recorded exhausted attempts as ${exhausted:-<missing>}"
  require_clean_doctor
  printf 'gc11-demo: expected halt after %s review attempt(s); no write-back performed\n' "$exhausted"
  exit 0
fi

root_outcome=$(jq -r 'if type == "array" then .[0].metadata["gc.outcome"] // "" else .metadata["gc.outcome"] // "" end' <<<"$root_json")
[[ $root_outcome == pass ]] || fail "successful mode ended with outcome ${root_outcome:-<missing>}"
for artifact in brief.md plan.md verify.md final.md; do
  [[ -s "$WORK_ROOT/$artifact" ]] || fail "missing workflow artifact: $WORK_ROOT/$artifact"
done
require_attempt_artifacts
if [[ $MODE == repair ]]; then
  jq -e '.attempt == 1 and .verdict == "fail"' "$WORK_ROOT/attempts/1/verdict.json" >/dev/null ||
    fail 'repair attempt 1 did not record the intentional failure'
  jq -e '.attempt == 2 and .verdict == "pass"' "$WORK_ROOT/attempts/2/verdict.json" >/dev/null ||
    fail 'repair attempt 2 did not pass'
fi
printf 'gc11-demo: verified durable workflow artifacts under %s\n' "$WORK_ROOT"

"${GC_CMD[@]}" bd close "$first_bead" --reason 'GC-11 demo workflow completed; explicit write-back follows' >/dev/null
(cd "$RIG_DIR" && GC_BACKLOG_SOURCE=backlog.md "$WRITEBACK_WRAPPER" "$TASK_ID") >"$STATE_DIR/writeback.json"
jq -e --arg bead "$first_bead" '.action == "marked_done" and .bead_id == $bead' "$STATE_DIR/writeback.json" >/dev/null || fail 'explicit write-back did not mark the imported bead done'
source_after_writeback=$(shasum -a 256 "$RIG_DIR/backlog.md")
[[ $source_before != "$source_after_writeback" ]] || fail 'explicit write-back did not change the source backlog'

require_clean_doctor
printf 'gc11-demo: %s workflow and explicit write-back passed; doctor clean\n' "$MODE"
