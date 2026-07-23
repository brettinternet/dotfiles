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

The default mode is happy. GC11_BEADS_READY_SECONDS, GC11_PREWARM_SECONDS,
GC11_WAIT_SECONDS, and GC11_POLL_SECONDS may be set for bounded store,
controller, and workflow polling (defaults: 60, 60, 3600, and 5).
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
BEADS_READY_SECONDS=${GC11_BEADS_READY_SECONDS:-60}

[[ $WAIT_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_WAIT_SECONDS must be a positive integer\n' >&2; exit 2; }
[[ $PREWARM_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_PREWARM_SECONDS must be a positive integer\n' >&2; exit 2; }
[[ $POLL_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_POLL_SECONDS must be a positive integer\n' >&2; exit 2; }
[[ $BEADS_READY_SECONDS =~ ^[1-9][0-9]*$ ]] || { printf 'GC11_BEADS_READY_SECONDS must be a positive integer\n' >&2; exit 2; }
PHASE_TEMPLATES=(
  fixture/gc.intake
  fixture/gc.planner
  fixture/gc.implementer
  fixture/gc.verifier
  fixture/gc.reviewer
)
PHASE_SESSION_IDS=()
PHASE_RESET_BEAD_IDS=("" "" "" "" "")
PHASE_RUNTIME_WAKE_KEYS=("" "" "" "" "")
PHASE_ACTIVE_REPLACEMENT_KEYS=("" "" "" "" "")
PHASE_NUDGE_KEYS=("" "" "" "" "")


CITY_GC_CMD=(mise exec -- gc --city "$CITY_DIR")
GC_CMD=(mise exec -- gc --city "$CITY_DIR" --rig fixture)
BD_CMD=(mise exec -- bd -C "$RIG_DIR")
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
wait_for_beads_store() {
  local deadline=$((SECONDS + BEADS_READY_SECONDS))
  local remaining sleep_for ready_err ready_diag
  ready_err="$TMP_DIR/beads-ready.err"

  while ((SECONDS < deadline)); do
    if "${BD_CMD[@]}" search - \
      --external-contains 'md:backlog.md#__gc11_readiness__' \
      --status all \
      --limit 1 \
      --json >/dev/null 2>"$ready_err"; then
      return 0
    fi
    remaining=$((deadline - SECONDS))
    ((remaining > 0)) || break
    sleep_for=$POLL_SECONDS
    ((sleep_for > remaining)) && sleep_for=$remaining
    sleep "$sleep_for"
  done

  ready_diag=
  [[ -s $ready_err ]] && ready_diag=$(tr '\n' ' ' <"$ready_err")
  fail "fixture Beads store was not ready within ${BEADS_READY_SECONDS}s${ready_diag:+; stderr=$ready_diag}"
}


valid_bead_id() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]*$ ]]
}
persist_phase_session() {
  local template=$1 session_id=$2 state_file state_tmp current
  case "$template" in
    fixture/gc.intake|fixture/gc.planner|fixture/gc.implementer|fixture/gc.verifier|fixture/gc.reviewer) ;;
    *) fail "refusing to record unknown phase template: $template" ;;
  esac
  valid_bead_id "$session_id" ||
    fail "refusing to record invalid phase session ID: $session_id"
  state_file="$STATE_DIR/phase-sessions.json"
  state_tmp="$STATE_DIR/.phase-sessions.json.$$"
  current='{}'
  [[ ! -f $state_file ]] || current=$(<"$state_file")
  jq -e 'type == "object"' <<<"$current" >/dev/null ||
    fail 'existing durable phase session state is malformed'
  if ! jq -c --arg template "$template" --arg session_id "$session_id" \
    '.[$template] = $session_id' <<<"$current" >"$state_tmp"; then
    [[ ! -e $state_tmp ]] || trash "$state_tmp"
    fail "cannot serialize durable phase session state for $template"
  fi
  if ! mv -f -- "$state_tmp" "$state_file"; then
    [[ ! -e $state_tmp ]] || trash "$state_tmp"
    fail "cannot persist phase session state for $template"
  fi
}



append_id() {
  local file=$1 id=$2
  valid_bead_id "$id" || fail "refusing to record invalid bead ID: $id"
  printf '%s\n' "$id" >>"$file"
}

recorded_ids_present() {
  [[ -f "$STATE_DIR/imported-bead-ids" || -f "$STATE_DIR/root-bead-ids" ]]
}

retire_recorded_sessions() {
  local work_json sessions_json roots_json recorded_sessions_json candidates
  local session_id active_other session_state close_json
  if [[ -f "$STATE_DIR/root-bead-ids" ]]; then
    roots_json=$(jq -Rsc 'split("\n") | map(select(length > 0)) | unique' \
      "$STATE_DIR/root-bead-ids") ||
      fail 'cannot parse recorded workflow roots before session retirement'
  else
    roots_json='[]'
  fi
  if [[ -f "$STATE_DIR/phase-sessions.json" ]]; then
    jq -e '
      type == "object" and
      ((keys - [
        "fixture/gc.intake",
        "fixture/gc.planner",
        "fixture/gc.implementer",
        "fixture/gc.verifier",
        "fixture/gc.reviewer"
      ]) | length == 0) and
      all(.[]; type == "string" and test("^[A-Za-z0-9][A-Za-z0-9_.:-]*$"))
    ' "$STATE_DIR/phase-sessions.json" >/dev/null ||
      fail 'durable phase session state is malformed; preserving recorded workflow'
    recorded_sessions_json=$(jq -c '[.[]] | unique' "$STATE_DIR/phase-sessions.json") ||
      fail 'cannot parse durable phase session identities'
  else
    recorded_sessions_json='[]'
    [[ ! -f "$STATE_DIR/root-bead-ids" ]] ||
      fail 'recorded workflow is missing durable phase session state; preserving it'
  fi
  if [[ $(jq -r 'length' <<<"$roots_json") == 0 &&
        $(jq -r 'length' <<<"$recorded_sessions_json") == 0 ]]; then
    return 0
  fi

  work_json=$("${GC_CMD[@]}" bd list --all --json --limit=0) ||
    fail 'cannot inspect workflow work before recorded session retirement'
  sessions_json=$("${GC_CMD[@]}" session list --state all --json) ||
    fail 'cannot inspect sessions before recorded workflow cleanup'
  jq -e 'type == "array" and all(.[]; type == "object")' <<<"$work_json" >/dev/null ||
    fail 'workflow work listing is malformed before recorded session retirement'
  jq -e 'type == "object" and (.sessions | type == "array") and all(.sessions[]; type == "object")' \
    <<<"$sessions_json" >/dev/null ||
    fail 'session listing is malformed before recorded workflow cleanup'
  candidates=$(jq -r \
    --argjson roots "$roots_json" \
    --argjson recorded "$recorded_sessions_json" \
    --argjson work "$work_json" '
    def identity_matches($value; $id):
      ($value // "") as $value |
      ($value == $id) or
      ($value == ("s-" + $id)) or
      ($value | endswith("-" + $id));
    [.sessions[] |
      (.id // .session_id // "") as $id |
      select($id != "") |
      select(
        (($recorded | index($id)) != null) or
        any($work[];
          ((.id // "") as $work_id |
            ((.metadata // {})["gc.root_bead_id"] // "") as $work_root |
            (($roots | index($work_id)) != null or
             ($roots | index($work_root)) != null)) and
          (
            identity_matches(.assignee; $id) or
            identity_matches((.metadata // {})["gc.session_name"]; $id)
          )
        )
      ) |
      $id] |
    unique[]
  ' <<<"$sessions_json") ||
    fail 'cannot derive recorded workflow session identities'

  while IFS= read -r session_id || [[ -n $session_id ]]; do
    [[ -n $session_id ]] || continue
    active_other=$(jq -er --arg session_id "$session_id" --argjson roots "$roots_json" '
      def identity_matches($value; $id):
        ($value // "") as $value |
        ($value == $id) or
        ($value == ("s-" + $id)) or
        ($value | endswith("-" + $id));
      [.[] | select(
        (.status == "in_progress" or (.status == "open" and (.assignee // "") != "")) and
        ((.id // "") as $work_id |
          ((.metadata // {})["gc.root_bead_id"] // "") as $work_root |
          (($roots | index($work_id)) == null and
           ($roots | index($work_root)) == null)) and
        (
          identity_matches(.assignee; $session_id) or
          identity_matches((.metadata // {})["gc.session_name"]; $session_id)
        )
      )] |
      length
    ' <<<"$work_json") ||
      fail "cannot inspect unrelated work before recorded session retirement: $session_id"
    ((active_other == 0)) ||
      fail "refusing to retire recorded workflow session with unrelated active work: $session_id"
    session_state=$(jq -er --arg session_id "$session_id" '
      [.sessions[] | select((.id // .session_id // "") == $session_id)] |
      if length != 1 then
        error("expected one exact session")
      elif (.[0].closed // false) or ((.[0].state // "") == "closed") then
        "closed"
      else
        "present"
      end
    ' <<<"$sessions_json") ||
      fail "cannot inspect exact recorded workflow session: $session_id"
    [[ $session_state == present ]] || continue
    close_json=$("${GC_CMD[@]}" session close "$session_id" --json) ||
      fail "cannot retire recorded workflow session: $session_id"
    jq -e '.ok == true and .state == "closed"' <<<"$close_json" >/dev/null ||
      fail "recorded workflow session did not close cleanly: $session_id"
    printf 'gc11-demo: retired recorded workflow session: %s\n' "$session_id"
  done <<<"$candidates"
}


delete_recorded_ids() {
  retire_recorded_sessions
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
  if recorded_ids_present; then
    "${GC_CMD[@]}" start --json >/dev/null ||
      fail 'cannot start existing fixture city before recorded workflow cleanup'
    wait_for_beads_store
    delete_recorded_ids
    trash "$STATE_DIR"
    "$MAKE_FIXTURE" >/dev/null
    wait_for_beads_store
    printf 'gc11-demo: reset recorded demo beads\n'
    return 0
  fi
  "$MAKE_FIXTURE" >/dev/null
  wait_for_beads_store
  [[ -d "$STATE_DIR" ]] && trash "$STATE_DIR"
  printf 'gc11-demo: no recorded demo beads; fixture refreshed\n'
}

if [[ $MODE == reset ]]; then
  reset_demo
  exit 0
fi

# A mode retires only a previous run's recorded sessions and graph before
# refreshing tracked fixture files, leaving unrelated rig work untouched.
if [[ -d "$STATE_DIR" ]]; then
  if recorded_ids_present; then
    "${GC_CMD[@]}" start --json >/dev/null ||
      fail 'cannot start existing fixture city before recorded workflow cleanup'
    wait_for_beads_store
    delete_recorded_ids
  fi
  trash "$STATE_DIR"
fi
"$MAKE_FIXTURE" >/dev/null
wait_for_beads_store
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
  local deadline remaining sleep_for phase_state_tmp
  PHASE_SESSION_IDS=()
  phase_state_tmp="$STATE_DIR/.phase-sessions.json.$$"
  printf '{}\n' >"$phase_state_tmp"
  if ! mv -f -- "$phase_state_tmp" "$STATE_DIR/phase-sessions.json"; then
    [[ ! -e $phase_state_tmp ]] || trash "$phase_state_tmp"
    fail 'cannot initialize durable phase session state'
  fi

  session_json=$("${GC_CMD[@]}" session list --state all --json) ||
    fail 'cannot list phase sessions before formula sling'
  for template in "${PHASE_TEMPLATES[@]}"; do
    if [[ $MODE == repair && $template == fixture/gc.implementer ]]; then
      PHASE_SESSION_IDS+=("")
      continue
    fi
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
    persist_phase_session "$template" "$session_id"
  done

  "${GC_CMD[@]}" supervisor reload >/dev/null ||
    fail 'cannot reload supervisor after preparing phase sessions'

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
  local deadline=$((SECONDS + BEADS_READY_SECONDS))
  local import_status import_diag remaining sleep_for
  local import_output="$TMP_DIR/import.out"
  local import_error="$TMP_DIR/import.err"
  IMPORT_RETRIED=0

  while :; do
    if (cd "$RIG_DIR" && GC_BACKLOG_SOURCE=backlog.md "$IMPORT_WRAPPER" "$TASK_ID") \
      >"$import_output" 2>"$import_error"; then
      cat "$import_output"
      return 0
    else
      import_status=$?
    fi
    import_diag=
    [[ -s $import_error ]] && import_diag=$(tr '\n' ' ' <"$import_error")
    if [[ $import_diag != *"Dolt server unreachable"* &&
          $import_diag != *"failed to open database"* &&
          $import_diag != *"can't assign requested address"* &&
          $import_diag != *"connection refused"* &&
          $import_diag != *"timed out"* ]]; then
      fail "backlog import failed (exit=$import_status${import_diag:+; stderr=$import_diag})"
    fi
    IMPORT_RETRIED=1
    remaining=$((deadline - SECONDS))
    ((remaining > 0)) ||
      fail "backlog import remained unavailable for ${BEADS_READY_SECONDS}s (exit=$import_status${import_diag:+; stderr=$import_diag})"
    sleep_for=$POLL_SECONDS
    ((sleep_for > remaining)) && sleep_for=$remaining
    sleep "$sleep_for"
  done
}

source_external_ref="md:backlog.md#$TASK_ID"
preimport_json=$("${GC_CMD[@]}" bd list --all --json --limit=0) ||
  fail "cannot inspect existing fixture import before first import: $source_external_ref"
preimport_count=$(jq -er --arg ref "$source_external_ref" '
  [.[] | select((.external_ref // "") == $ref)] | length
' <<<"$preimport_json") ||
  fail "cannot count existing fixture imports before first import: $source_external_ref"
((preimport_count == 0)) ||
  fail "fixture source was already imported before this demo run (external_ref=$source_external_ref count=$preimport_count)"

run_import >"$STATE_DIR/import-1.json"
first_action=$(jq -er '.action | strings' "$STATE_DIR/import-1.json")
if [[ $first_action != created &&
      ! ($first_action == skipped && $IMPORT_RETRIED == 1) ]]; then
  fail "first import did not create or recover this run's demo-owned bead (action=$first_action retried=$IMPORT_RETRIED)"
fi
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
  persist_phase_session "$template" "$replacement_id"
  replacement_wake_err="$TMP_DIR/demand-replacement-wake-${i}.err"
  if "${GC_CMD[@]}" session wake "$replacement_id" --json >/dev/null 2>"$replacement_wake_err"; then
    :
  else
    replacement_wake_status=$?
    replacement_wake_diag=
    [[ -s $replacement_wake_err ]] && replacement_wake_diag=$(tr '\n' ' ' <"$replacement_wake_err")
    fail "phase-demand replacement failure: cannot wake replacement session (root=$root_id template=$template old=$old_session_id new=$replacement_id wake_exit=$replacement_wake_status${replacement_wake_diag:+; stderr=$replacement_wake_diag})"
  fi
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
  local i template template_short session_id hook_json hook_status hook_err hook_diag
  local matching_ready ready_total ready_ids_json ready_bead_id active_json active_other
  local active_ids_json active_count active_bead_id active_session_identity active_session_id
  local session_json session_match_json session_template
  local selected_active_count retire_status retire_err retire_diag
  local nudge_status nudge_err nudge_diag reset_status reset_err reset_diag
  local runtime_status runtime_err runtime_diag runtime_alive
  local wake_status wake_err wake_diag session_state
  local -a reset_templates=()

  for i in "${!PHASE_TEMPLATES[@]}"; do
    template=${PHASE_TEMPLATES[$i]}
    session_id=${PHASE_SESSION_IDS[$i]}
    active_json=$("${GC_CMD[@]}" bd list --all --json --limit=0) ||
      fail "cannot inspect assigned phase work (root=$root_id template=$template session=$session_id)"
    active_ids_json=$(jq -cer \
      --arg root_id "$root_id" \
      --arg template "$template" '
      [.[] | select(
        (.status == "in_progress" or (.status == "open" and (.assignee // "") != ""))
        and ((.metadata // {})["gc.root_bead_id"] // "") == $root_id
        and ((.metadata // {})["gc.kind"] // "") != "workflow"
        and ((.metadata // {})["gc.kind"] // "") != "ralph"
        and ((.metadata // {})["gc.kind"] // "") != "spec"
        and ((.metadata // {})["gc.kind"] // "") != "workflow-finalize"
        and (
          ((.metadata // {})["gc.routed_to"] // "") == $template
          or ((.metadata // {})["gc.run_target"] // "") == $template
          or ((.metadata // {})["gc.execution_routed_to"] // "") == $template
        )
      ) | {
        id,
        session: (if (.assignee // "") != "" then .assignee else ((.metadata // {})["gc.session_name"] // "") end)
      }]
    ' <<<"$active_json") ||
      fail "cannot parse assigned phase work (root=$root_id template=$template)"
    active_count=$(jq -er 'length' <<<"$active_ids_json") ||
      fail "cannot count assigned phase work (root=$root_id template=$template)"
    ((active_count <= 1)) ||
      fail "phase route has multiple assigned beads (root=$root_id template=$template count=$active_count)"
    if ((active_count == 1)); then
      active_bead_id=$(jq -er '.[0].id | select(type == "string" and length > 0)' <<<"$active_ids_json") ||
        fail "cannot identify assigned phase bead (root=$root_id template=$template)"
      active_session_identity=$(jq -er '.[0].session | select(type == "string" and length > 0)' <<<"$active_ids_json") ||
        fail "assigned phase bead has no session identity (root=$root_id template=$template bead=$active_bead_id)"
      session_json=$("${GC_CMD[@]}" session list --state all --json) ||
        fail "cannot inspect assigned phase session (root=$root_id template=$template identity=$active_session_identity)"
      session_match_json=$(jq -cer --arg identity "$active_session_identity" '
        def normalize: sub("^s-"; "");
        [.sessions[] |
          . as $session |
          [$session.id?, $session.session_id?, $session.name?, $session.session_name?, $session.alias?] |
          map(select(type == "string" and length > 0)) |
          select(any(. == $identity or ((. | normalize) == ($identity | normalize)))) |
          $session
        ] |
        if length == 1 then {
          id: (.[0].id // .[0].session_id // ""),
          template: (.[0].template // .[0].template_name // ""),
          state: (.[0].state // "")
        }
        elif length == 0 then {id: "", template: "", state: ""}
        else error("assigned session identity is not unique")
        end
      ' <<<"$session_json") ||
        fail "cannot resolve assigned phase session (root=$root_id template=$template identity=$active_session_identity)"
      active_session_id=$(jq -er '.id | select(type == "string")' <<<"$session_match_json") ||
        fail "assigned phase session has no canonical ID (root=$root_id template=$template identity=$active_session_identity)"
      session_template=$(jq -er '.template | select(type == "string")' <<<"$session_match_json") ||
        fail "assigned phase session has no template (root=$root_id template=$template session=${active_session_id:-<missing>})"
      session_state=$(jq -er '.state | select(type == "string")' <<<"$session_match_json") ||
        fail "assigned phase session has no state (root=$root_id template=$template session=${active_session_id:-<missing>})"
      if [[ -z $active_session_id ]]; then
        if [[ ${PHASE_ACTIVE_REPLACEMENT_KEYS[i]} == "$active_session_identity:$session_id:$active_bead_id" ]]; then
          active_session_id=$session_id
          session_template=$template
          session_state=active
        else
          fail "cannot resolve assigned phase session (root=$root_id template=$template identity=$active_session_identity)"
        fi
      fi
      [[ $session_template == "$template" ]] ||
        fail "assigned phase session template mismatch (root=$root_id template=$template session=$active_session_id actual=$session_template)"
      if [[ -z $session_id ]]; then
        :
      elif [[ $active_session_id != "$session_id" ]]; then
        if [[ ${PHASE_ACTIVE_REPLACEMENT_KEYS[i]} == "$active_session_identity:$session_id:$active_bead_id" ]]; then
          active_session_id=$session_id
        else
          selected_active_count=$(jq -er --arg session_id "$session_id" '
            [.[] | select(
              (.status == "in_progress" or (.status == "open" and (.assignee // "") != ""))
              and (
                (.assignee // "") == $session_id
                or (.assignee // "") == ("s-" + $session_id)
                or ((.assignee // "") | endswith("-" + $session_id))
                or ((.metadata // {})["gc.session_name"] // "") == $session_id
                or ((.metadata // {})["gc.session_name"] // "") == ("s-" + $session_id)
                or (((.metadata // {})["gc.session_name"] // "") | endswith("-" + $session_id))
              )
            )] | length
          ' <<<"$active_json") ||
            fail "cannot inspect superseded phase session work (root=$root_id template=$template session=$session_id)"
          ((selected_active_count == 0)) ||
            fail "refusing to retire superseded phase session with active work (root=$root_id template=$template session=$session_id count=$selected_active_count)"
          retire_err="$TMP_DIR/retire-${i}.err"
          if "${GC_CMD[@]}" session close "$session_id" --json >/dev/null 2>"$retire_err"; then
            :
          else
            retire_status=$?
            retire_diag=
            [[ -s $retire_err ]] && retire_diag=$(tr '\n' ' ' <"$retire_err")
            if [[ $retire_diag != *"$session_id"* ]] ||
               [[ ! $retire_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
              fail "cannot retire superseded phase session (root=$root_id template=$template session=$session_id exit=$retire_status${retire_diag:+; stderr=$retire_diag})"
            fi
          fi
        fi
      fi
      PHASE_SESSION_IDS[i]=$active_session_id
      persist_phase_session "$template" "$active_session_id"
      session_id=$active_session_id
      runtime_alive=false
      runtime_err="$TMP_DIR/runtime-${i}.err"
      runtime_diag=
      runtime_status=0
      if [[ $session_state == active || $session_state == draining ]]; then
        if "${GC_CMD[@]}" session peek "$session_id" --json --lines 1 >/dev/null 2>"$runtime_err"; then
          runtime_alive=true
        else
          runtime_status=$?
          [[ -s $runtime_err ]] && runtime_diag=$(tr '\n' ' ' <"$runtime_err")
          if [[ ! $runtime_diag =~ (no[[:space:]]+tmux[[:space:]]+server|session[[:space:]]+(is[[:space:]]+)?not[[:space:]]+(active|found)) ]]; then
            fail "cannot inspect assigned phase session runtime (root=$root_id template=$template session=$session_id bead=$active_bead_id state=$session_state exit=$runtime_status${runtime_diag:+; stderr=$runtime_diag})"
          fi
        fi
      else
        runtime_status=1
        runtime_diag="session state $session_state"
      fi
      if [[ $runtime_alive == true ]]; then
        if [[ ${PHASE_NUDGE_KEYS[i]} != "$session_id:$active_bead_id" ]]; then
          nudge_err="$TMP_DIR/nudge-${i}.err"
          if "${GC_CMD[@]}" session nudge "$session_id" \
            "Bead $active_bead_id is already assigned to this exact $template session and in_progress. Do not run gc hook again; treat it as claimed, inspect it with gc bd show $active_bead_id --json, follow that bead's description through every durable artifact and gc.output_json requirement, close only that phase bead, and stop." \
            --delivery immediate --json >/dev/null 2>"$nudge_err"; then
            PHASE_NUDGE_KEYS[i]="$session_id:$active_bead_id"
          else
            nudge_status=$?
            nudge_diag=
            [[ -s $nudge_err ]] && nudge_diag=$(tr '\n' ' ' <"$nudge_err")
            fail "cannot nudge assigned phase session (root=$root_id template=$template session=$session_id bead=$active_bead_id exit=$nudge_status${nudge_diag:+; stderr=$nudge_diag})"
          fi
        fi
      else
        PHASE_NUDGE_KEYS[i]=
        if [[ ${PHASE_RUNTIME_WAKE_KEYS[i]} == "$session_id:$active_bead_id" ]]; then
          continue
        fi
        printf 'gc11-demo: recovering inactive assigned phase session root=%s template=%s session=%s bead=%s state=%s\n' \
          "$root_id" "$template" "$session_id" "$active_bead_id" "${session_state:-missing}"
        reset_err="$TMP_DIR/assigned-reset-${i}.err"
        if "${GC_CMD[@]}" session reset "$session_id" --json >/dev/null 2>"$reset_err"; then
          :
        else
          reset_status=$?
          reset_diag=
          [[ -s $reset_err ]] && reset_diag=$(tr '\n' ' ' <"$reset_err")
          if [[ $reset_diag == *"$session_id"* ]] &&
             [[ $reset_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
            replace_ready_phase_session "$i" "$template" "$session_id"
            PHASE_ACTIVE_REPLACEMENT_KEYS[i]="$active_session_identity:${PHASE_SESSION_IDS[i]}:$active_bead_id"
            PHASE_RUNTIME_WAKE_KEYS[i]="${PHASE_SESSION_IDS[i]}:$active_bead_id"
            reset_templates+=("$template")
            continue
          fi
          fail "cannot reset inactive assigned phase session (root=$root_id template=$template session=$session_id bead=$active_bead_id exit=$reset_status${reset_diag:+; stderr=$reset_diag})"
        fi
        wake_err="$TMP_DIR/assigned-wake-${i}.err"
        if "${GC_CMD[@]}" session wake "$session_id" --json >/dev/null 2>"$wake_err"; then
          :
        else
          wake_status=$?
          wake_diag=
          [[ -s $wake_err ]] && wake_diag=$(tr '\n' ' ' <"$wake_err")
          if [[ $wake_diag == *"$session_id"* ]] &&
             [[ $wake_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
            replace_ready_phase_session "$i" "$template" "$session_id"
            PHASE_ACTIVE_REPLACEMENT_KEYS[i]="$active_session_identity:${PHASE_SESSION_IDS[i]}:$active_bead_id"
            PHASE_RUNTIME_WAKE_KEYS[i]="${PHASE_SESSION_IDS[i]}:$active_bead_id"
            reset_templates+=("$template")
            continue
          fi
          fail "cannot wake inactive assigned phase session (root=$root_id template=$template session=$session_id bead=$active_bead_id exit=$wake_status${wake_diag:+; stderr=$wake_diag})"
        fi
        PHASE_RUNTIME_WAKE_KEYS[i]="$session_id:$active_bead_id"
        reset_templates+=("$template")
        continue
      fi
      continue
    fi
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
    ready_ids_json=$(jq -cer --arg root "$root_id" '
      [.[] | select((.metadata // {})["gc.root_bead_id"] == $root)] as $matching
      | if all($matching[]; (.id | type) == "string" and (.id | length) > 0)
        then [$matching[].id]
        else error("matching hook work has no valid bead ID")
        end
    ' <<<"$hook_json") ||
      fail "cannot identify ready phase work for $template (session=$session_id)"
    ready_total=$(jq -er 'length' <<<"$hook_json") ||
      fail "cannot count hook work for $template (session=$session_id)"
    if ((matching_ready > 0)); then
      ready_bead_id=$(jq -er 'if length == 1 then .[0] else error("expected exactly one ready bead") end' <<<"$ready_ids_json") ||
        fail "cannot select one ready phase bead for $template (root=$root_id session=$session_id count=$matching_ready)"
      ((ready_total == matching_ready)) ||
        fail "refusing to reset phase session with unrelated ready work (root=$root_id template=$template session=$session_id total=$ready_total matching=$matching_ready)"
      if [[ $MODE == repair && $template == fixture/gc.implementer && -z $session_id ]]; then
        continue
      fi
      template_short=${template#*/}
      active_json=$("${GC_CMD[@]}" bd list --all --json --limit=0) ||
        fail "cannot inspect active phase work before reset (root=$root_id template=$template session=$session_id)"
      active_other=$(jq -er \
        --arg root_id "$root_id" \
        --arg template "$template" \
        --arg template_short "$template_short" \
        --argjson ready_ids "$ready_ids_json" \
        --arg session_id "$session_id" '
        [.[] | select(
          (.status == "in_progress" or (.status == "open" and (.assignee // "") != ""))
          and ((.metadata // {})["gc.kind"] // "") != "workflow"
          and ((.metadata // {})["gc.kind"] // "") != "ralph"
          and ((.metadata // {})["gc.kind"] // "") != "spec"
          and ((.metadata // {})["gc.kind"] // "") != "workflow-finalize"
          and (.id as $id | ($ready_ids | index($id)) == null)
          and (
            (.assignee // "") == $session_id
            or (.assignee // "") == ("s-" + $session_id)
            or ((.assignee // "") | endswith("-" + $session_id))
            or ((.metadata // {})["gc.session_name"] // "") == $session_id
            or ((.metadata // {})["gc.session_name"] // "") == ("s-" + $session_id)
            or (((.metadata // {})["gc.session_name"] // "") | endswith("-" + $session_id))
            or (
              ((.metadata // {})["gc.root_bead_id"] // "") == $root_id
              and (
                ((.metadata // {})["gc.routed_to"] // "") == $template
                or ((.metadata // {})["gc.routed_to"] // "") == $template_short
                or ((.metadata // {})["gc.run_target"] // "") == $template
                or ((.metadata // {})["gc.run_target"] // "") == $template_short
                or ((.metadata // {})["gc.execution_routed_to"] // "") == $template
                or ((.metadata // {})["gc.execution_routed_to"] // "") == $template_short
              )
            )
          )
        )] | length
      ' <<<"$active_json") ||
        fail "cannot parse active phase work before reset (root=$root_id template=$template session=$session_id)"
      ((active_other == 0)) ||
        fail "refusing to reset phase session with unrelated active work (root=$root_id template=$template session=$session_id count=$active_other)"
    fi
    if ((matching_ready > 0)) &&
       [[ $MODE == repair && $template == fixture/gc.implementer ]]; then
      retire_err="$TMP_DIR/repair-implementer-retire-${i}.err"
      if "${GC_CMD[@]}" session close "$session_id" --json >/dev/null 2>"$retire_err"; then
        :
      else
        retire_status=$?
        retire_diag=
        [[ -s $retire_err ]] && retire_diag=$(tr '\n' ' ' <"$retire_err")
        if [[ $retire_diag != *"$session_id"* ]] ||
           [[ ! $retire_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
          fail "cannot retire completed repair implementer session (root=$root_id template=$template session=$session_id exit=$retire_status${retire_diag:+; stderr=$retire_diag})"
        fi
      fi
      PHASE_SESSION_IDS[i]=
      PHASE_RUNTIME_WAKE_KEYS[i]=
      PHASE_ACTIVE_REPLACEMENT_KEYS[i]=
      reset_templates+=("$template")
      continue
    fi
    if ((matching_ready > 0)); then
      if [[ ${PHASE_RESET_BEAD_IDS[i]} == "$ready_bead_id" ]]; then
        session_state=$(session_state_for_reset "$i" "$template" "$session_id")
        case "$session_state" in
          present)
            break
            ;;
          missing|closed)
            replace_ready_phase_session "$i" "$template" "$session_id"
            PHASE_RESET_BEAD_IDS[i]=$ready_bead_id
            PHASE_RUNTIME_WAKE_KEYS[i]="${PHASE_SESSION_IDS[i]}:$ready_bead_id"
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
          PHASE_RESET_BEAD_IDS[i]=$ready_bead_id
          PHASE_RUNTIME_WAKE_KEYS[i]="${PHASE_SESSION_IDS[i]}:$ready_bead_id"
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
          PHASE_RESET_BEAD_IDS[i]=$ready_bead_id
          PHASE_RUNTIME_WAKE_KEYS[i]="${PHASE_SESSION_IDS[i]}:$ready_bead_id"
          reset_templates+=("$template")
          break
        fi
        fail "cannot wake reset session (root=$root_id template=$template session=$session_id exit=$wake_status${wake_diag:+; stderr=$wake_diag})"
      fi
      PHASE_RESET_BEAD_IDS[i]=$ready_bead_id
      PHASE_RUNTIME_WAKE_KEYS[i]="$session_id:$ready_bead_id"
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
  local deadline=$((SECONDS + WAIT_SECONDS)) terminal_deadline=0
  local root_json status outcome remaining sleep_for
  while ((SECONDS < deadline)); do
    if ((terminal_deadline == 0)); then
      wake_ready_phase_sessions
    fi
    root_json=$("${GC_CMD[@]}" bd show "$root_id" --json 2>/dev/null || true)
    if [[ -n $root_json ]]; then
      printf '%s\n' "$root_json" >"$STATE_DIR/workflow-state.json"
      status=$(jq -r 'if type == "array" then .[0].status // "" else .status // "" end' <<<"$root_json" 2>/dev/null || true)
      if [[ $status == closed ]]; then
        outcome=$(jq -r 'if type == "array" then .[0].metadata["gc.outcome"] // "" else .metadata["gc.outcome"] // "" end' <<<"$root_json" 2>/dev/null || true)
        if [[ $outcome == pass || $outcome == fail ]]; then
          return 0
        fi
        if ((terminal_deadline == 0)); then
          terminal_deadline=$((SECONDS + BEADS_READY_SECONDS))
        elif ((SECONDS >= terminal_deadline)); then
          fail "closed workflow root $root_id did not expose gc.outcome within ${BEADS_READY_SECONDS}s"
        fi
      fi
    fi
    remaining=$((deadline - SECONDS))
    if ((terminal_deadline > 0 && terminal_deadline - SECONDS < remaining)); then
      remaining=$((terminal_deadline - SECONDS))
    fi
    ((remaining > 0)) || break
    sleep_for=$POLL_SECONDS
    ((sleep_for > remaining)) && sleep_for=$remaining
    sleep "$sleep_for"
  done
  if ((terminal_deadline > 0)); then
    fail "closed workflow root $root_id did not expose gc.outcome within ${BEADS_READY_SECONDS}s"
  fi
  fail "workflow root $root_id did not reach a terminal state within ${WAIT_SECONDS}s"
}

close_phase_sessions() {
  local deadline=$((SECONDS + WAIT_SECONDS))
  local work_json active_phase active_other i template template_short session_id session_state
  local hook_json hook_status hook_err hook_diag hook_count
  local close_status close_err close_diag remaining sleep_for

  for i in "${!PHASE_TEMPLATES[@]}"; do
    template=${PHASE_TEMPLATES[$i]}
    template_short=${template#*/}
    session_id=${PHASE_SESSION_IDS[$i]-}
    [[ -n $session_id ]] ||
      fail "final phase session ID is missing (root=$root_id template=$template session=<missing>)"
    hook_count=-1
    active_phase=-1
    active_other=-1

    while ((SECONDS < deadline)); do
      work_json=$("${GC_CMD[@]}" bd list --all --json --limit=0) ||
        fail "cannot inspect phase work before closing sessions for root $root_id"
      jq -e 'type == "array" and all(.[]; type == "object")' >/dev/null <<<"$work_json" ||
        fail "phase work listing is malformed before closing sessions for root $root_id"

      hook_err="$TMP_DIR/close-hook-${i}.err"
      hook_json=
      if hook_json=$(cd "$RIG_DIR" && "${GC_CMD[@]}" hook "$template" --json 2>"$hook_err"); then
        hook_status=0
      else
        hook_status=$?
      fi
      hook_diag=
      [[ -s $hook_err ]] && hook_diag=$(tr '\n' ' ' <"$hook_err")
      if [[ -z ${hook_json//[[:space:]]/} ]]; then
        ((hook_status == 0 || hook_status == 1)) ||
          fail "cannot inspect ready phase work before close (root=$root_id template=$template session=$session_id exit=$hook_status${hook_diag:+; stderr=$hook_diag})"
        hook_json='[]'
      elif ((hook_status != 0 && hook_status != 1)); then
        fail "cannot inspect ready phase work before close (root=$root_id template=$template session=$session_id exit=$hook_status${hook_diag:+; stderr=$hook_diag})"
      fi
      hook_count=$(jq -er --arg root "$root_id" 'if type == "array" then [.[] | select(((.metadata // {})["gc.root_bead_id"] // "") == $root)] | length else error("hook result is not an array") end' <<<"$hook_json") ||
        fail "cannot parse ready phase work before close (root=$root_id template=$template session=$session_id)"

      active_phase=$(jq -er \
        --arg root_id "$root_id" \
        --arg template "$template" \
        --arg template_short "$template_short" \
        --arg session_id "$session_id" '
        [.[] | select(
          (.status == "in_progress" or (.status == "open" and (.assignee // "") != ""))
          and ((.metadata // {})["gc.kind"] // "") != "workflow"
          and ((.metadata // {})["gc.kind"] // "") != "ralph"
          and ((.metadata // {})["gc.kind"] // "") != "spec"
          and ((.metadata // {})["gc.kind"] // "") != "workflow-finalize"
          and ((.metadata // {})["gc.root_bead_id"] // "") == $root_id
          and (
            (.assignee // "") == $session_id
            or (.assignee // "") == ("s-" + $session_id)
            or ((.assignee // "") | endswith("-" + $session_id))
            or ((.metadata // {})["gc.session_name"] // "") == $session_id
            or ((.metadata // {})["gc.session_name"] // "") == ("s-" + $session_id)
            or (((.metadata // {})["gc.session_name"] // "") | endswith("-" + $session_id))
            or ((.metadata // {})["gc.routed_to"] // "") == $template
            or ((.metadata // {})["gc.routed_to"] // "") == $template_short
            or ((.metadata // {})["gc.run_target"] // "") == $template
            or ((.metadata // {})["gc.run_target"] // "") == $template_short
            or ((.metadata // {})["gc.execution_routed_to"] // "") == $template
            or ((.metadata // {})["gc.execution_routed_to"] // "") == $template_short
          )
        )] | length
      ' <<<"$work_json") ||
        fail "cannot inspect active phase work (root=$root_id template=$template session=$session_id)"
      active_other=$(jq -er \
        --arg root_id "$root_id" \
        --arg session_id "$session_id" '
        [.[] | select(
          (.status == "in_progress" or (.status == "open" and (.assignee // "") != ""))
          and ((.metadata // {})["gc.root_bead_id"] // "") != $root_id
          and (
            (.assignee // "") == $session_id
            or (.assignee // "") == ("s-" + $session_id)
            or ((.assignee // "") | endswith("-" + $session_id))
            or ((.metadata // {})["gc.session_name"] // "") == $session_id
            or ((.metadata // {})["gc.session_name"] // "") == ("s-" + $session_id)
            or (((.metadata // {})["gc.session_name"] // "") | endswith("-" + $session_id))
          )
        )] | length
      ' <<<"$work_json") ||
        fail "cannot inspect unrelated session work (root=$root_id template=$template session=$session_id)"
      ((active_other == 0)) ||
        fail "refusing to close phase session with unrelated active work (root=$root_id template=$template session=$session_id count=$active_other)"
      ((hook_count == 0 && active_phase == 0)) && break

      remaining=$((deadline - SECONDS))
      ((remaining > 0)) || break
      sleep_for=$POLL_SECONDS
      ((sleep_for > remaining)) && sleep_for=$remaining
      sleep "$sleep_for"
    done
    ((hook_count == 0 && active_phase == 0)) ||
      fail "phase session work did not drain within ${WAIT_SECONDS}s (root=$root_id template=$template session=$session_id ready=$hook_count active=$active_phase)"

    session_state=$(session_state_for_reset "$i" "$template" "$session_id")
    case "$session_state" in
      missing|closed)
        continue
        ;;
      present)
        ;;
      *)
        fail "cannot inspect phase session before close (root=$root_id template=$template session=$session_id state=$session_state)"
        ;;
    esac
    close_err="$TMP_DIR/close-${i}.err"
    if "${GC_CMD[@]}" session close "$session_id" --json >/dev/null 2>"$close_err"; then
      continue
    else
      close_status=$?
    fi
    close_diag=
    [[ -s $close_err ]] && close_diag=$(tr '\n' ' ' <"$close_err")
    if [[ $close_diag == *"$session_id"* ]] &&
       [[ $close_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
      continue
    fi
    fail "cannot close completed phase session (root=$root_id template=$template session=$session_id exit=$close_status${close_diag:+; stderr=$close_diag})"
  done
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

require_fresh_repair_sessions() {
  local repair_sessions_json
  repair_sessions_json=$("${GC_CMD[@]}" bd list --all --json --limit=0) ||
    fail "cannot inspect repair attempt sessions for workflow root: $root_id"
  jq -e --arg root "$root_id" '
    [.[] | select(
      .title == "Implement backlog item" and
      .status == "closed" and
      ((.metadata // {})["gc.root_bead_id"] // "") == $root
    ) | {
      attempt: (((.metadata // {})["gc.attempt"] // "") | tostring),
      session: ((
        if ((.metadata // {})["gc.session_name"] // "") != ""
        then (.metadata // {})["gc.session_name"]
        else (.assignee // "")
        end
      ) | sub("^s-"; ""))
    }] |
    map(select(.attempt == "1" or .attempt == "2")) |
    sort_by(.attempt) |
    (length == 2) and
    ([.[].attempt] == ["1", "2"]) and
    (all(.[].session; type == "string" and length > 0)) and
    (.[0].session != .[1].session)
  ' <<<"$repair_sessions_json" >/dev/null ||
    fail 'repair attempts did not run in two distinct implementer sessions'
}

require_resolvable_final_bead_refs() {
  local bead_ref bead_json ref_root ref_count=0
  while IFS= read -r bead_ref; do
    [[ -n $bead_ref ]] || continue
    ((ref_count += 1))
    bead_json=$("${GC_CMD[@]}" bd show "$bead_ref" --json) ||
      fail "final report contains an unresolved fixture bead reference: $bead_ref"
    ref_root=$(jq -er '
      if type == "array" then .[0] else . end |
      (.metadata // {})["gc.root_bead_id"] // ""
    ' <<<"$bead_json") ||
      fail "cannot inspect final report bead reference: $bead_ref"
    if [[ $bead_ref != "$root_id" && $bead_ref != "$first_bead" && $ref_root != "$root_id" ]]; then
      fail "final report bead reference is outside the source/workflow graph: $bead_ref"
    fi
  done < <(LC_ALL=C grep -Eo 'fx-[A-Za-z0-9]+' "$WORK_ROOT/final.md" | LC_ALL=C sort -u)
  ((ref_count > 0)) ||
    fail 'final report contains no resolvable fixture bead references'
}

fixture_changed_files() {
  local tracked untracked path
  tracked=$(git -C "$RIG_DIR" diff --name-only HEAD --) || return
  untracked=$(git -C "$RIG_DIR" ls-files --others --exclude-standard) || return
  while IFS= read -r path || [[ -n $path ]]; do
    [[ -n $path ]] || continue
    case "$path" in
      .gascity|.gascity/*|.omp|.omp/*|.local/fixture-rig/.omp|.local/fixture-rig/.omp/*) continue ;;
    esac
    printf '%s\n' "$path"
  done <<<"$tracked"$'\n'"$untracked"
}


require_success_phase_outputs() {
  local phase_json outputs_json changed_files report
  phase_json=$("${GC_CMD[@]}" bd list --all --json --limit=0) ||
    fail "cannot inspect verify/finalize phase outputs for workflow root: $root_id"
  outputs_json=$(jq -cer --arg root "$root_id" '
    def phase_output($title):
      [.[] | select(
        .title == $title and
        ((.metadata // {})["gc.root_bead_id"] // "") == $root
      )] |
      if length == 1 then
        (.[0].metadata["gc.output_json"] // "" | fromjson)
      else
        error("expected exactly one matching phase")
      end;
    {
      verify: phase_output("Verify backlog item"),
      finalize: phase_output("Finalize backlog item")
    }
  ' <<<"$phase_json") ||
    fail 'successful workflow did not persist one structured verify and finalize phase output'
  changed_files=$(fixture_changed_files | LC_ALL=C sort -u) ||
    fail 'cannot inspect successful workflow repository changes'
  [[ $changed_files == AGENTS.md ]] ||
    fail "successful fixture workflow changed unexpected files: ${changed_files:-<none>}"
  jq -e \
    --arg root "$root_id" \
    --arg verify_artifact ".gascity/work/$root_id/verify.md" \
    --arg final_artifact ".gascity/work/$root_id/final.md" '
    .verify.phase == "verify" and
    .verify.status == "complete" and
    .verify.workflow_root == $root and
    .verify.artifact == $verify_artifact and
    .verify.changed_files == ["AGENTS.md"] and
    .verify.outcome == "pass" and
    .finalize.phase == "finalize" and
    .finalize.status == "complete" and
    .finalize.workflow_root == $root and
    .finalize.artifact == $final_artifact and
    .finalize.outcome == "pass" and
    .finalize.changed_files == .verify.changed_files
  ' <<<"$outputs_json" >/dev/null ||
    fail 'successful workflow verify/finalize outputs did not record complete pass artifacts'
  if grep -Eiq '^[-[:space:]#*]*(result|status|outcome)[[:space:]*:—-]+(blocked|fail(ed)?|incomplete)([^[:alpha:]]|$)' \
    "$WORK_ROOT/verify.md" "$WORK_ROOT/final.md"; then
    fail 'successful workflow report contains an explicit blocked/failed/incomplete outcome'
  fi
  for report in "$WORK_ROOT/attempts/1/report.md" "$WORK_ROOT/verify.md" "$WORK_ROOT/final.md"; do
    grep -Fq 'AGENTS.md' "$report" ||
      fail "successful workflow report omits the tracked AGENTS.md change: $report"
  done
  if grep -Eiq 'no (source |repository |file )?changes (were )?required|(source |repository |file )?changes (were )?not required|required no (source |repository |file )?changes|(comment|marker) was already (present|contained)|implementation (was )?not required' \
    "$WORK_ROOT/attempts/1/report.md" "$WORK_ROOT/verify.md" "$WORK_ROOT/final.md"; then
    fail 'successful workflow report contradicts the tracked AGENTS.md change'
  fi
  if grep -Eiq '^[[:space:]]*\|?[[:space:]]*implement(ation)?[[:space:]]*\|[^|]*(not (a )?phase|non-phase)' \
    "$WORK_ROOT/final.md"; then
    fail 'successful final report mislabels the implementation phase'
  fi
}


run_doctor() {
  if "${GC_CMD[@]}" doctor --json >"$STATE_DIR/doctor.json"; then
    return 0
  else
    return $?
  fi
}

run_critical_stale_orders() {
  local critical_detail scoped_name
  while IFS= read -r critical_detail; do
    [[ -n $critical_detail ]] || continue
    scoped_name=${critical_detail%%: last fired *}
    [[ $scoped_name =~ ^[A-Za-z0-9._-]+(:rig:[A-Za-z0-9._-]+)?$ ]] ||
      fail "cannot safely parse critically stale order: $critical_detail"
    case "$scoped_name" in
      mol-dog-stale-db:rig:fixture)
        "${GC_CMD[@]}" order run mol-dog-stale-db --json >/dev/null ||
          fail "cannot run critically stale fixture order: $scoped_name"
        ;;
      mol-dog-stale-db)
        "${CITY_GC_CMD[@]}" order run mol-dog-stale-db --json >/dev/null ||
          fail "cannot run critically stale city order: $scoped_name"
        ;;
      *:rig:*)
        fail "doctor reported a critically stale order outside the fixture rig: $scoped_name"
        ;;
      *)
        fail "doctor reported an unrelated critically stale city order: $scoped_name"
        ;;
    esac
    printf 'gc11-demo: dispatched critically stale order: %s\n' "$scoped_name" >&2
  done < <(jq -r '
    .results[]
    | select(.name == "order-firing-current")
    | .details[]
    | select(test("^mol-dog-stale-db(:rig:fixture)?: last fired ") and endswith("(CRITICAL: stale)"))
  ' "$STATE_DIR/doctor.json")
}

require_clean_doctor() {
  local critical doctor_status=0 doctor_attempt doctor_max_attempts=6
  for ((doctor_attempt = 1; doctor_attempt <= doctor_max_attempts; doctor_attempt++)); do
    if run_doctor; then
      doctor_status=0
    else
      doctor_status=$?
    fi
    if jq -e '(.failed == 0) and (.blocking_failed == 0)' "$STATE_DIR/doctor.json" >/dev/null; then
      return 0
    fi
    if ! jq -e '
      (.failed == 1) and
      (.blocking_failed == 1) and
      ([.results[] | select(.status != "ok" and .status != "warning") | .name] | unique == ["order-firing-current"])
    ' "$STATE_DIR/doctor.json" >/dev/null; then
      break
    fi
    ((doctor_attempt < doctor_max_attempts)) || break
    if ((doctor_attempt == 1)); then
      printf 'gc11-demo: reconciling the fixture controller before bounded doctor retries\n' >&2
      "${CITY_GC_CMD[@]}" supervisor reload >/dev/null ||
        fail 'cannot reload supervisor for post-workflow doctor recovery'
      "${GC_CMD[@]}" start --json >/dev/null ||
        fail 'cannot reconcile fixture city for post-workflow doctor recovery'
      run_critical_stale_orders
    fi
    critical=$(jq -cr '
      [.results[]
        | select(.name == "order-firing-current")
        | .details[]
        | select(endswith("(CRITICAL: stale)"))]
    ' "$STATE_DIR/doctor.json")
    printf 'gc11-demo: waiting %ss for tracked controller order firing before doctor retry %s/%s: %s\n' \
      "$PREWARM_SECONDS" "$((doctor_attempt + 1))" "$doctor_max_attempts" "$critical" >&2
    sleep "$PREWARM_SECONDS"
  done
  fail "gc doctor --json was not clean after $doctor_max_attempts bounded controller-order checks (exit=$doctor_status)"
}
wait_for_workflow

root_json=$(cat "$STATE_DIR/workflow-state.json")
root_status=$(jq -r 'if type == "array" then .[0].status // "" else .status // "" end' <<<"$root_json")
[[ $root_status == closed ]] || fail "workflow root did not close (status=${root_status:-<missing>})"
close_phase_sessions
wait_for_phase_sessions_closed
root_failure=$(jq -r 'if type == "array" then .[0].metadata["gc.failure_class"] // "" else .metadata["gc.failure_class"] // "" end' <<<"$root_json")
WORK_ROOT="$RIG_DIR/.gascity/work/$root_id"
if [[ $MODE == halt ]]; then
  for artifact in brief.md plan.md; do
    [[ -s "$WORK_ROOT/$artifact" ]] || fail "missing workflow artifact: $WORK_ROOT/$artifact"
  done
  [[ -s "$WORK_ROOT/final.md" ]] ||
    fail "missing failed final report after halt: $WORK_ROOT/final.md"
  require_resolvable_final_bead_refs
  [[ ! -e "$WORK_ROOT/verify.md" ]] ||
    fail "halt unexpectedly produced verification evidence: $WORK_ROOT/verify.md"
  grep -Eiq 'fail|exhaust' "$WORK_ROOT/final.md" ||
    fail 'halt final report does not describe the failed/exhausted outcome'
  finalize_output=$("${GC_CMD[@]}" bd list --all --json --limit=0 | jq -cer --arg root "$root_id" '
    [.[] |
      select(
        .title == "Finalize backlog item" and
        ((.metadata // {})["gc.root_bead_id"] // "") == $root
      )] |
    if length == 1 then
      (.[0].metadata["gc.output_json"] // "" | fromjson)
    else
      error("expected exactly one finalize phase")
    end
  ') || fail 'halt finalizer did not persist one structured phase output'
  jq -e \
    --arg root "$root_id" \
    --arg artifact ".gascity/work/$root_id/final.md" '
    .phase == "finalize" and
    .status == "complete" and
    .workflow_root == $root and
    .outcome == "fail" and
    .artifact == $artifact
  ' <<<"$finalize_output" >/dev/null ||
    fail 'halt finalizer output did not record the failed final report'
  require_attempt_artifacts
  jq -e '.attempt == 1 and .verdict == "fail"' "$WORK_ROOT/attempts/1/verdict.json" >/dev/null ||
    fail 'halt attempt 1 did not record the expected failure verdict'
  [[ $root_failure == review_attempts_exhausted ]] || fail 'halt did not record review-attempt exhaustion metadata'
  exhausted=$(jq -r 'if type == "array" then .[0].metadata["gc.exhausted_attempts"] // "" else .metadata["gc.exhausted_attempts"] // "" end' <<<"$root_json")
  [[ $exhausted == 1 ]] || fail "halt recorded exhausted attempts as ${exhausted:-<missing>}"
  halt_root_outcome=$(jq -r 'if type == "array" then .[0].metadata["gc.outcome"] // "" else .metadata["gc.outcome"] // "" end' <<<"$root_json")
  [[ $halt_root_outcome == fail ]] ||
    fail "halt workflow root ended with outcome ${halt_root_outcome:-<missing>}"
  source_after_halt=$(shasum -a 256 "$RIG_DIR/backlog.md")
  [[ $source_before == "$source_after_halt" ]] ||
    fail 'halt mutated the source backlog without explicit write-back'
  source_bead_status=$("${GC_CMD[@]}" bd show "$first_bead" --json | jq -er '
    if type == "array" then .[0].status else .status end
  ') || fail 'cannot inspect imported source bead after halt'
  [[ $source_bead_status != closed ]] ||
    fail 'halt closed the imported source bead without explicit write-back'
  require_clean_doctor
  printf 'gc11-demo: expected halt after %s review attempt(s); no write-back performed\n' "$exhausted"
  exit 0
fi

root_outcome=$(jq -r 'if type == "array" then .[0].metadata["gc.outcome"] // "" else .metadata["gc.outcome"] // "" end' <<<"$root_json")
[[ $root_outcome == pass ]] || fail "successful mode ended with outcome ${root_outcome:-<missing>}"
for artifact in brief.md plan.md verify.md final.md; do
  [[ -s "$WORK_ROOT/$artifact" ]] || fail "missing workflow artifact: $WORK_ROOT/$artifact"
done
require_resolvable_final_bead_refs
require_success_phase_outputs
require_attempt_artifacts
if [[ $MODE == repair ]]; then
  jq -e '.attempt == 1 and .verdict == "fail"' "$WORK_ROOT/attempts/1/verdict.json" >/dev/null ||
    fail 'repair attempt 1 did not record the intentional failure'
  jq -e '.attempt == 2 and .verdict == "pass"' "$WORK_ROOT/attempts/2/verdict.json" >/dev/null ||
    fail 'repair attempt 2 did not pass'
  require_fresh_repair_sessions
fi
printf 'gc11-demo: verified durable workflow artifacts under %s\n' "$WORK_ROOT"

"${GC_CMD[@]}" bd close "$first_bead" --reason 'GC-11 demo workflow completed; explicit write-back follows' >/dev/null
(cd "$RIG_DIR" && GC_BACKLOG_SOURCE=backlog.md "$WRITEBACK_WRAPPER" "$TASK_ID") >"$STATE_DIR/writeback.json"
jq -e --arg bead "$first_bead" '.action == "marked_done" and .bead_id == $bead' "$STATE_DIR/writeback.json" >/dev/null || fail 'explicit write-back did not mark the imported bead done'
source_after_writeback=$(shasum -a 256 "$RIG_DIR/backlog.md")
[[ $source_before != "$source_after_writeback" ]] || fail 'explicit write-back did not change the source backlog'

require_clean_doctor
printf 'gc11-demo: %s workflow and explicit write-back passed; doctor clean\n' "$MODE"
