#!/usr/bin/env bash
# Run the implement-step reviewer and persist the bounded-loop evidence.

set -euo pipefail

fail() {
  printf 'review-check: %s\n' "$*" >&2
  exit 2
}

SCRIPT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
script_deadline=$((SECONDS + 840))
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gc-review-check.XXXXXX")
trap 'trash "$tmp_dir" 2>/dev/null || true' EXIT
run_until_deadline_at() {
  local deadline=$1 command_cwd=$2 stdout_file=$3 stderr_file=$4
  shift 4
  (($# > 0)) || return 2

  (
    cd "$command_cwd"
    exec "$@"
  ) >"$stdout_file" 2>"$stderr_file" &
  local command_pid=$!

  while :; do
    if ! kill -0 "$command_pid" 2>/dev/null; then
      if wait "$command_pid"; then
        return 0
      else
        local command_status=$?
        return "$command_status"
      fi
    fi
    if ((SECONDS >= deadline)); then
      kill -TERM "$command_pid" 2>/dev/null || true
      kill -KILL "$command_pid" 2>/dev/null || true
      wait "$command_pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
  done
}
run_until_deadline() {
  local deadline=$1 stdout_file=$2 stderr_file=$3
  shift 3
  run_until_deadline_at "$deadline" "$REPO_ROOT" "$stdout_file" "$stderr_file" "$@"
}

if [[ -n ${GC_REVIEW_CHECK_ROOT:-} ]]; then
  REPO_ROOT=$(cd -- "$GC_REVIEW_CHECK_ROOT" && pwd)
elif [[ -d "$PWD/.gascity/work" ]]; then
  REPO_ROOT=$PWD
elif [[ -n ${BEADS_DIR:-} && -d ${BEADS_DIR} ]]; then
  REPO_ROOT=$(cd -- "$BEADS_DIR/.." && pwd)
elif [[ -n ${GC_RIG:-} ]]; then
  rig_lookup_deadline=$((script_deadline - 810))
  rig_output_file="$tmp_dir/rig-status.out"
  rig_err="$tmp_dir/rig-status.err"
  run_until_deadline_at "$rig_lookup_deadline" "$PWD" "$rig_output_file" "$rig_err" \
    gc rig status "$GC_RIG" --json ||
    fail "cannot inspect configured rig within startup deadline: $GC_RIG"
  rig_json=$(<"$rig_output_file")
  rig_path=$(jq -er '.rig.path // .path' <<<"$rig_json") ||
    fail "configured rig has no path: $GC_RIG"
  REPO_ROOT=$(cd -- "$rig_path" && pwd)
elif [[ -d "$SCRIPT_ROOT/.gascity/work" ]]; then
  REPO_ROOT=$SCRIPT_ROOT
else
  REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || fail 'cannot locate the rig repository'
fi

WORK_ROOT=${GC_WORKFLOW_ROOT:-}
if [[ -n $WORK_ROOT ]]; then
  [[ $WORK_ROOT == /* ]] ||
    WORK_ROOT="$REPO_ROOT/.gascity/work/$WORK_ROOT"
elif [[ -n ${GC_ROOT_BEAD_ID:-} ]]; then
  WORK_ROOT="$REPO_ROOT/.gascity/work/$GC_ROOT_BEAD_ID"
elif [[ -n ${GC_MOLECULE_DIR:-} ]]; then
  molecule_root_id=${GC_MOLECULE_DIR%/}
  molecule_root_id=${molecule_root_id##*/}
  [[ -n $molecule_root_id ]] ||
    fail "GC_MOLECULE_DIR does not identify a workflow root"
  WORK_ROOT="$REPO_ROOT/.gascity/work/$molecule_root_id"
elif [[ -n ${GC_BEAD_ID:-} ]]; then
  root_lookup_deadline=$((script_deadline - 810))
  root_lookup_output_file="$tmp_dir/assigned-bead.out"
  root_lookup_err="$tmp_dir/assigned-bead.err"
  run_until_deadline "$root_lookup_deadline" "$root_lookup_output_file" "$root_lookup_err" \
    gc bd show "$GC_BEAD_ID" --json ||
    fail "cannot read assigned bead within startup deadline: $GC_BEAD_ID"
  bead_json=$(<"$root_lookup_output_file")
  root_id=$(jq -er '
    if type == "array" then .[0].metadata["gc.root_bead_id"]
    else .metadata["gc.root_bead_id"]
    end
  ' <<<"$bead_json") || fail "assigned bead has no workflow root: $GC_BEAD_ID"
  WORK_ROOT="$REPO_ROOT/.gascity/work/$root_id"
else
  work_base="$REPO_ROOT/.gascity/work"
  [[ -d $work_base ]] || fail "missing workflow directory: $work_base"
  shopt -s nullglob
  plan_paths=("$work_base"/*/plan.md)
  shopt -u nullglob
  ((${#plan_paths[@]} == 1)) || fail "GC_WORKFLOW_ROOT, GC_MOLECULE_DIR, or GC_BEAD_ID is required when workflow plans are ambiguous"
  WORK_ROOT=${plan_paths[0]%/plan.md}
fi

prepare_review_context() {
  local report_path attempt_name
  local identity_deadline=$((script_deadline - 360))
  local identity_output_file="$tmp_dir/reviewer-user.out"
  local identity_err="$tmp_dir/reviewer-user.err"

  preflight_failure=
  [[ -d $WORK_ROOT ]] || {
    preflight_failure="missing workflow root: $WORK_ROOT"
    return 1
  }
  PLAN=$WORK_ROOT/plan.md
  [[ -f $PLAN ]] || {
    preflight_failure="missing plan: $PLAN"
    return 1
  }

  attempt=${GC_ITERATION:-${GC_ATTEMPT:-}}
  if [[ -n $attempt ]]; then
    [[ $attempt =~ ^[0-9]+$ ]] || {
      preflight_failure="invalid review iteration: $attempt"
      return 1
    }
    report="$WORK_ROOT/attempts/$attempt/report.md"
    [[ -f $report ]] || {
      preflight_failure="missing implementer report for iteration $attempt"
      return 1
    }
  else
    attempt=-1
    report=
    for report_path in "$WORK_ROOT"/attempts/*/report.md; do
      [[ -f $report_path ]] || continue
      attempt_name=${report_path%/report.md}
      attempt_name=${attempt_name##*/}
      [[ $attempt_name =~ ^[0-9]+$ ]] || continue
      if ((attempt_name > attempt)); then
        attempt=$attempt_name
        report=$report_path
      fi
    done
    ((attempt >= 1)) || {
      preflight_failure="no implementer report found below $WORK_ROOT/attempts"
      return 1
    }
  fi

  attempt_dir=${report%/report.md}
  input=$attempt_dir/reviewer-input.md
  verdict_file=$attempt_dir/verdict.json
  review_file=$attempt_dir/review.md
  schema='{"type":"object","additionalProperties":false,"properties":{"verdict":{"type":"string","enum":["pass","fail"]},"findings":{"type":"array","items":{"type":"string"}}},"required":["verdict","findings"]}'
  reviewer=${GC_REVIEW_CHECK_CLAUDE:-claude}
  run_until_deadline "$identity_deadline" "$identity_output_file" "$identity_err" id -un || {
    preflight_failure="cannot resolve runtime user within the preflight deadline"
    return 1
  }
  user_name=$(<"$identity_output_file")
  [[ $user_name =~ ^[a-zA-Z0-9._-]+$ ]] || {
    preflight_failure="invalid runtime user: $user_name"
    return 1
  }
  eval "reviewer_home=~$user_name" || {
    preflight_failure="cannot resolve runtime home for user: $user_name"
    return 1
  }
  if [[ $reviewer == claude ]] && ! command -v "$reviewer" >/dev/null 2>&1; then
    mise_claude=${MISE_DATA_DIR:-$reviewer_home/.local/share/mise}/installs/claude/latest/claude
    local_claude=$reviewer_home/.local/bin/claude
    if [[ -x $mise_claude ]]; then
      reviewer=$mise_claude
    elif [[ -x $local_claude ]]; then
      reviewer=$local_claude
    fi
  fi
  reviewer_timeout=${GC_REVIEW_CHECK_CLAUDE_TIMEOUT_SECONDS:-90}
  if [[ ! $reviewer_timeout =~ ^[1-9][0-9]*$ ]] || ((reviewer_timeout > 90)); then
    preflight_failure="invalid Claude reviewer timeout: $reviewer_timeout (expected 1-90 seconds)"
    return 1
  fi
  raw_output=$tmp_dir/reviewer.json
  raw_error=$tmp_dir/reviewer.err
}

build_review_input() {
  local input_deadline=$((script_deadline - 360))
  local tracked_file="$tmp_dir/review-tracked.z"
  local repo_diff_file="$tmp_dir/review-repo.diff"
  local untracked_file="$tmp_dir/review-untracked.z"
  local untracked_output_file="$tmp_dir/review-untracked.diff"
  local git_err="$tmp_dir/review-git.err"
  local tracked_path untracked_path untracked_output diff_status
  local repo_diff untracked_diff report_files_lines report_files_json
  local derived_changed_files_json

  ((SECONDS < input_deadline)) || {
    input_failure="review input deadline expired before repository inspection"
    return 1
  }
  changed_files=()
  run_until_deadline "$input_deadline" "$tracked_file" "$git_err" \
    git diff --name-only -z HEAD -- || {
    input_failure="cannot list tracked review changes within the input deadline"
    return 1
  }
  while IFS= read -r -d '' tracked_path; do
    case $tracked_path in
      .gascity|.gascity/*|.omp|.omp/*|.local/fixture-rig/.omp|.local/fixture-rig/.omp/*) continue ;;
    esac
    changed_files+=("$tracked_path")
  done <"$tracked_file"

  run_until_deadline "$input_deadline" "$repo_diff_file" "$git_err" \
    git diff --no-ext-diff HEAD -- . || {
    input_failure="cannot read tracked review diff within the input deadline"
    return 1
  }
  repo_diff=$(<"$repo_diff_file")
  untracked_diff=
  run_until_deadline "$input_deadline" "$untracked_file" "$git_err" \
    git ls-files --others --exclude-standard -z || {
    input_failure="cannot list untracked review changes within the input deadline"
    return 1
  }
  while IFS= read -r -d '' untracked_path; do
    case $untracked_path in
      .gascity|.gascity/*|.omp|.omp/*|.local/fixture-rig/.omp|.local/fixture-rig/.omp/*) continue ;;
    esac
    changed_files+=("$untracked_path")
    if run_until_deadline "$input_deadline" "$untracked_output_file" "$git_err" \
      git diff --no-ext-diff --no-index /dev/null "$REPO_ROOT/$untracked_path"; then
      diff_status=0
    else
      diff_status=$?
    fi
    ((diff_status == 0 || diff_status == 1)) || {
      input_failure="cannot read untracked review diff within the input deadline: $untracked_path"
      return 1
    }
    untracked_output=$(<"$untracked_output_file")
    untracked_diff+=$untracked_output
    untracked_diff+=$'\n'
  done <"$untracked_file"
  if [[ -n $repo_diff && -n $untracked_diff ]]; then
    repo_diff+=$'\n'
  fi
  repo_diff+=$untracked_diff
  [[ -n $repo_diff ]] || {
    input_failure="implementation produced no uncommitted repository diff for review"
    return 1
  }
  report_files_lines=$(grep -E \
    '^[[:space:]]*-[[:space:]]+Files changed:' \
    "$report" || true)
  [[ -n $report_files_lines ]] || {
    input_failure='implementer report is missing its "- Files changed: <JSON array>" field'
    return 1
  }
  (( $(grep -Ec \
    '^[[:space:]]*-[[:space:]]+Files changed:' \
    "$report") == 1 )) || {
    input_failure='implementer report must contain exactly one "- Files changed: <JSON array>" field'
    return 1
  }
  report_files_json=${report_files_lines#*:}
  report_files_json=${report_files_json#"${report_files_json%%[![:space:]]*}"}
  derived_changed_files_json=$(printf '%s\0' "${changed_files[@]}" |
    jq -Rsc 'split("\u0000") | map(select(length > 0)) | sort | unique')
  jq -e --argjson expected "$derived_changed_files_json" '
    type == "array" and
    all(.[]; type == "string" and length > 0) and
    . == $expected
  ' <<<"$report_files_json" >/dev/null 2>&1 || {
    input_failure="implementer report changed-file set does not match repository diff: expected $derived_changed_files_json"
    return 1
  }
  ((SECONDS < input_deadline)) || {
    input_failure="review input deadline expired during repository inspection"
    return 1
  }
  {
    printf '# Review input\n\n'
    printf 'This input is limited to the current plan, its acceptance criteria, the current repository diff (including non-ignored untracked files), and the latest implementer report. Do not inspect prior reports, transcripts, or other workflow artifacts.\n\n'
    printf '## Plan and acceptance criteria\n\n'
    cat "$PLAN"
    # shellcheck disable=SC2016
    printf '\n## Current repository diff\n\n```diff\n%s\n```\n' "$repo_diff"
    printf '\n## Latest implementer report (attempt %s)\n\n' "$attempt"
    cat "$report"
  } >"$input" || {
    input_failure="cannot write bounded reviewer input"
    return 1
  }
}


write_verdict_artifacts() {
  jq -n \
    --arg workflow_root "${WORK_ROOT##*/}" \
    --argjson attempt "$attempt" \
    --arg verdict "$provider_verdict" \
    --arg reviewer "$reviewer" \
    --arg input "${input#"$REPO_ROOT"/}" \
    --argjson findings "$findings" \
    '{workflow_root:$workflow_root,attempt:$attempt,verdict:$verdict,reviewer:$reviewer,input:$input,findings:$findings}' \
    >"$verdict_file" || return 1

  {
    printf '# Review attempt %s\n\n' "$attempt"
    # shellcheck disable=SC2016
    printf -- '- Verdict: **%s**\n- Reviewer: `%s`\n- Input: `%s`\n\n' "$provider_verdict" "$reviewer" "${input#"$REPO_ROOT"/}"
    printf '## Findings\n\n'
    if ((${#findings} == 2)); then
      printf -- '- None.\n'
    else
      jq -r '.[] | "- " + .' <<<"$findings" || return 1
    fi
  } >"$review_file" || return 1
}

persist_reviewer_failure() {
  local reviewer_label=$1 message=$2
  reviewer=$reviewer_label
  provider_verdict=fail
  findings=$(jq -nc --arg finding "$message" '[$finding]') ||
    abort_failed_review "${WORK_ROOT##*/}" \
      "cannot encode reviewer infrastructure failure" \
      "attempt=$attempt"
  write_verdict_artifacts ||
    abort_failed_review "${WORK_ROOT##*/}" \
      "cannot persist reviewer failure artifacts" \
      "attempt=$attempt"
  printf 'review-check: %s\n' "$message" >&2
  finalize_failed_review "${WORK_ROOT##*/}" "$message"
}

fixture_fail_once_requested() {
  grep -Fq 'fixture:fail-once' "$PLAN" "$WORK_ROOT/brief.md" 2>/dev/null &&
    return 0

  local workflow_root root_json source_id source_json source_text lookup_deadline
  local root_output_file="$tmp_dir/fixture-root.out"
  local root_err="$tmp_dir/fixture-root.err"
  local source_output_file="$tmp_dir/fixture-source.out"
  local source_err="$tmp_dir/fixture-source.err"
  workflow_root=${WORK_ROOT##*/}
  lookup_deadline=$((script_deadline - 360))
  run_until_deadline "$lookup_deadline" "$root_output_file" "$root_err" \
    gc bd show "$workflow_root" --json ||
    return 1
  root_json=$(<"$root_output_file")
  source_id=$(jq -er '
    if type == "array" then .[0].metadata["gc.var.item"]
    else .metadata["gc.var.item"]
    end
  ' <<<"$root_json") || return 1
  run_until_deadline "$lookup_deadline" "$source_output_file" "$source_err" \
    gc bd show "$source_id" --json ||
    return 1
  source_json=$(<"$source_output_file")
  source_text=$(jq -er '
    if type == "array" then .[0] else . end |
    [.title, .description] |
    map(. // "") |
    join("\n")
  ' <<<"$source_json") || return 1
  [[ $source_text == *'fixture:fail-once'* ]]
}
abort_failed_review() {
  local workflow_root=$1 failure_reason=$2 session_context=${3:-}
  local metadata_reason=$failure_reason
  local update_output update_status=0 update_diag
  local delete_output delete_status=0 delete_diag
  local restore_output restore_status=0 restore_diag
  local root_json root_status root_read_status=0 root_diag
  local update_output_file="$tmp_dir/review-abort-update.out"
  local delete_output_file="$tmp_dir/review-abort-delete.out"
  local restore_output_file="$tmp_dir/review-abort-restore.out"
  local root_output_file="$tmp_dir/review-abort-root.out"
  local update_err="$tmp_dir/review-abort-update.err"
  local delete_err="$tmp_dir/review-abort-delete.err"
  local restore_err="$tmp_dir/review-abort-restore.err"
  local root_err="$tmp_dir/review-abort-root.err"
  local root_parse_err="$tmp_dir/review-abort-root-parse.err"
  local -a update_args

  if [[ -n $session_context ]]; then
    metadata_reason+="; session_context=$session_context"
  fi
  update_args=(
    gc bd update "$workflow_root"
    --set-metadata gc.outcome=fail
    --set-metadata gc.failure_class=review_session_retirement_unverified
    --set-metadata "gc.failure_reason=$metadata_reason"
  )
  [[ -n $session_context ]] &&
    update_args+=(--set-metadata "gc.review_session_context=$session_context")

  if run_until_deadline "$script_deadline" "$update_output_file" "$update_err" "${update_args[@]}"; then
    update_status=0
  else
    update_status=$?
  fi
  update_output=$(<"$update_output_file")
  update_diag=
  [[ -n $update_output ]] && update_diag=$(tr '\n' ' ' <<<"$update_output")
  [[ -s $update_err ]] && update_diag+=" $(tr '\n' ' ' <"$update_err")"

  if run_until_deadline "$script_deadline" "$delete_output_file" "$delete_err" \
    gc convoy delete "$workflow_root" --force; then
    delete_status=0
  else
    delete_status=$?
  fi
  delete_output=$(<"$delete_output_file")
  delete_diag=
  [[ -n $delete_output ]] && delete_diag=$(tr '\n' ' ' <<<"$delete_output")
  [[ -s $delete_err ]] && delete_diag+=" $(tr '\n' ' ' <"$delete_err")"

  # convoy delete may apply its own skipped outcome while closing beads; restore
  # the durable failure metadata before checking the terminal root state.
  if run_until_deadline "$script_deadline" "$restore_output_file" "$restore_err" "${update_args[@]}"; then
    restore_status=0
  else
    restore_status=$?
  fi
  restore_output=$(<"$restore_output_file")
  restore_diag=
  [[ -n $restore_output ]] && restore_diag=$(tr '\n' ' ' <<<"$restore_output")
  [[ -s $restore_err ]] && restore_diag+=" $(tr '\n' ' ' <"$restore_err")"

  if run_until_deadline "$script_deadline" "$root_output_file" "$root_err" \
    gc bd show "$workflow_root" --json; then
    root_read_status=0
    root_json=$(<"$root_output_file")
    if root_status=$(jq -er '
      if type == "array" then .[0].status else .status end |
      select(type == "string")
    ' <<<"$root_json" 2>"$root_parse_err"); then
      :
    else
      root_status=
      root_read_status=1
    fi
  else
    root_read_status=$?
    root_json=$(<"$root_output_file")
    root_status=
  fi
  root_diag=
  [[ -n $root_json ]] && root_diag=$(tr '\n' ' ' <<<"$root_json")
  [[ -s $root_err ]] &&
    root_diag+=" $(tr '\n' ' ' <"$root_err")"
  [[ -s $root_parse_err ]] &&
    root_diag+=" $(tr '\n' ' ' <"$root_parse_err")"

  if [[ $root_status == closed && $restore_status -eq 0 ]]; then
    printf 'review-check: failed-review finalization aborted workflow root %s after retirement uncertainty (root status=closed; reason=%s%s); suppressing the Ralph retry signal\n' \
      "$workflow_root" "$failure_reason" \
      "${session_context:+; session_context=$session_context}" >&2
    exit 0
  fi

  printf 'review-check: failed-review retirement uncertainty; could not confirm workflow root %s closed (reason=%s%s; update_exit=%s%s; delete_exit=%s%s; restore_exit=%s%s; root_exit=%s; root_status=%s%s)\n' \
    "$workflow_root" "$failure_reason" \
    "${session_context:+; session_context=$session_context}" \
    "$update_status" "${update_diag:+; update=$update_diag}" \
    "$delete_status" "${delete_diag:+; delete=$delete_diag}" \
    "$restore_status" "${restore_diag:+; restore=$restore_diag}" \
    "$root_read_status" "${root_status:-<unknown>}" "${root_diag:+; root=$root_diag}" >&2
  exit 2
}

retire_failed_implementer_session() {
  local workflow_root=$1 attempt_number=$2 beads_json=$3 control_id=$4
  local attempt_bead_json attempt_identity_json
  local sessions_json session_match_json session_resolution_state canonical_session_id session_template
  local resolved_identities_json active_beads_json active_list_status active_list_diag
  local active_count close_output close_status close_diag
  local retirement_timeout retirement_poll retirement_deadline retirement_remaining retirement_sleep
  local retirement_sessions_json retirement_session_state retirement_list_status retirement_list_diag
  local session_context="attempt=$attempt_number"
  local retirement_list_output_file="$tmp_dir/retire-implementer-session-list.out"
  local retirement_list_err="$tmp_dir/retire-implementer-session-list.err"
  local close_output_file="$tmp_dir/retire-implementer-session.out"
  local close_err="$tmp_dir/retire-implementer-session.err"
  local active_beads_output_file="$tmp_dir/retire-implementer-active-beads.out"
  local active_beads_err="$tmp_dir/retire-implementer-active-beads.err"

  retirement_timeout=${GC_REVIEW_CHECK_SESSION_CLOSE_TIMEOUT_SECONDS:-180}
  retirement_poll=${GC_REVIEW_CHECK_SESSION_CLOSE_POLL_SECONDS:-1}
  [[ $retirement_timeout =~ ^[1-9][0-9]*$ ]] ||
    abort_failed_review "$workflow_root" \
      "invalid implementer session retirement timeout: $retirement_timeout (expected a positive integer)" \
      "attempt=$attempt_number"
  ((retirement_timeout <= 300)) ||
    abort_failed_review "$workflow_root" \
      "invalid implementer session retirement timeout: $retirement_timeout (expected 1-300 seconds)" \
      "attempt=$attempt_number"
  [[ $retirement_poll =~ ^[1-9][0-9]*$ ]] ||
    abort_failed_review "$workflow_root" \
      "invalid implementer session retirement poll interval: $retirement_poll (expected a positive integer)" \
      "attempt=$attempt_number"
  ((retirement_poll <= retirement_timeout)) ||
    abort_failed_review "$workflow_root" \
      "invalid implementer session retirement poll interval: $retirement_poll (must not exceed timeout $retirement_timeout)" \
      "attempt=$attempt_number"

  attempt_bead_json=$(jq -cer \
    --arg root "$workflow_root" \
    --arg attempt "$attempt_number" '
    def partial_retry:
      ((.metadata // {})["gc.partial_retry"] // false) as $partial |
      ($partial == true or
        (($partial | type) == "string" and ($partial | ascii_downcase) == "true"));
    def nonempty_string:
      if type == "string" then length > 0 else false end;
    if type != "array" or any(.[]; type != "object") then
      error("backlog listing is not an object array")
    else
      [.[] |
        select((.metadata // {}) | type == "object") |
        select(
          .title == "Implement backlog item" and
          .status == "closed" and
          ((.metadata // {})["gc.root_bead_id"] // "") == $root and
          (partial_retry | not) and
          (
            ((.metadata // {})["gc.routed_to"] // "") == "fixture/gc.implementer" or
            ((.metadata // {})["gc.run_target"] // "") == "fixture/gc.implementer" or
            ((.metadata // {})["gc.execution_routed_to"] // "") == "fixture/gc.implementer"
          )
        ) |
        select(
          ((.metadata // {})["gc.attempt"] // null) as $bead_attempt |
          (try ($bead_attempt | tonumber) catch null) == ($attempt | tonumber)
        ) |
        (.metadata // {}) as $metadata |
        {
          seed_identity: (
            if ($metadata["gc.session_name"] | nonempty_string) then
              $metadata["gc.session_name"]
            elif (.assignee? | nonempty_string) then
              .assignee
            else
              ""
            end
          )
        }
      ] |
      if length != 1 then
        error("expected exactly one closed implementer attempt")
      elif (.[0].seed_identity | nonempty_string | not) then
        error("closed implementer attempt has no session identity")
      else
        .[0]
      end
    end
  ' <<<"$beads_json") ||
    abort_failed_review "$workflow_root" \
      "cannot identify exactly one closed implementer attempt (root=$workflow_root attempt=$attempt_number)" \
      "$session_context"
  attempt_identity_json=$(jq -cer '.seed_identity' <<<"$attempt_bead_json") ||
    abort_failed_review "$workflow_root" \
      "closed implementer attempt has no session identity (root=$workflow_root attempt=$attempt_number)" \
      "$session_context"
  session_context+=" identity=$attempt_identity_json"

  retirement_deadline=$((SECONDS + retirement_timeout))
  ((retirement_deadline > script_deadline - 60)) &&
    retirement_deadline=$((script_deadline - 60))
  if run_until_deadline "$retirement_deadline" "$retirement_list_output_file" "$retirement_list_err" \
    gc session list --state all --json; then
    retirement_list_status=0
  else
    retirement_list_status=$?
    sessions_json=$(<"$retirement_list_output_file")
    retirement_list_diag=
    [[ -n $sessions_json ]] &&
      retirement_list_diag=$(tr '\n' ' ' <<<"$sessions_json")
    [[ -s $retirement_list_err ]] &&
      retirement_list_diag+=" $(tr '\n' ' ' <"$retirement_list_err")"
    abort_failed_review "$workflow_root" \
      "cannot inspect implementer sessions (root=$workflow_root attempt=$attempt_number exit=$retirement_list_status${retirement_list_diag:+; diagnostic=$retirement_list_diag})" \
      "$session_context"
  fi
  sessions_json=$(<"$retirement_list_output_file")
  session_match_json=$(jq -cer --arg seed_identity "$attempt_identity_json" '
    def normalize: sub("^s-"; "");
    def identity_matches($value; $identity):
      if ($value | type) != "string" or ($value | length) == 0 or
         ($identity | type) != "string" or ($identity | length) == 0 then
        false
      else
        ($value == $identity) or
        (($value | normalize) == ($identity | normalize))
      end;
    def identity_values:
      (.metadata // {}) as $metadata |
      [
        .id?, .session_id?, .name?, .session_name?, .alias?, .agent_name?,
        $metadata.id?, $metadata.session_id?, $metadata.name?,
        $metadata.session_name?, $metadata.alias?, $metadata.agent_name?,
        $metadata["gc.id"]?, $metadata["gc.session_id"]?,
        $metadata["gc.name"]?, $metadata["gc.session_name"]?,
        $metadata["gc.alias"]?, $metadata["gc.agent_name"]?,
        $metadata.configured_named_identity?
      ] | map(select(type == "string" and length > 0)) | unique;
    def sessions:
      if type == "array" then
        .
      elif type == "object" and (.sessions? | type) == "array" then
        .sessions
      else
        error("session listing is malformed")
      end;
    def closed_string:
      if type == "string" then ascii_downcase == "closed" else false end;
    def terminal_closed:
      (.closed? == true) or
      ((.state? // "") | closed_string) or
      ((.status? // "") | closed_string);
    (sessions) as $sessions |
    if any($sessions[]; type != "object" or ((.metadata // {}) | type) != "object") then
      error("session listing is malformed")
    else
      [$sessions[] |
        . as $session |
        ($session | identity_values) as $session_identities |
        select(any($session_identities[]?;
          identity_matches(.; $seed_identity)
        )) |
        {session: $session, identities: $session_identities}
      ] |
      if length == 0 then
        {
          state: "missing",
          id: ($seed_identity | normalize),
          template: "fixture/gc.implementer",
          identities: ([$seed_identity, ($seed_identity | normalize)] | unique)
        }
      elif length != 1 then
        error("implementer session identity is not unique")
      else
        {
          state: (if (.[0].session | terminal_closed) then "closed" else "present" end),
          id: ([
            .[0].session.id?, .[0].session.session_id?,
            (.[0].session.metadata // {})["id"]?,
            (.[0].session.metadata // {})["session_id"]?,
            (.[0].session.metadata // {})["gc.id"]?,
            (.[0].session.metadata // {})["gc.session_id"]?
          ] | map(select(type == "string" and length > 0)) | .[0] // ""),
          template: (
            .[0].session.template? // .[0].session.template_name? //
            (.[0].session.metadata // {})["template"]? //
            (.[0].session.metadata // {})["gc.template"]? // ""
          ),
          identities: .[0].identities
        }
      end
    end
  ' <<<"$sessions_json") ||
    abort_failed_review "$workflow_root" \
      "cannot resolve exactly one implementer session (root=$workflow_root attempt=$attempt_number)" \
      "$session_context"
  session_resolution_state=$(jq -er '.state | select(. == "missing" or . == "closed" or . == "present")' <<<"$session_match_json") ||
    abort_failed_review "$workflow_root" \
      "implementer session has invalid state (root=$workflow_root attempt=$attempt_number)" \
      "$session_context"
  canonical_session_id=$(jq -er '.id | select(type == "string" and length > 0)' <<<"$session_match_json") ||
    abort_failed_review "$workflow_root" \
      "implementer session has no canonical ID (root=$workflow_root attempt=$attempt_number)" \
      "$session_context"
  session_context+=" canonical=$canonical_session_id"
  session_template=$(jq -er '.template | select(type == "string" and length > 0)' <<<"$session_match_json") ||
    abort_failed_review "$workflow_root" \
      "implementer session has no template (root=$workflow_root attempt=$attempt_number session=$canonical_session_id)" \
      "$session_context"
  resolved_identities_json=$(jq -cer '.identities' <<<"$session_match_json") ||
    abort_failed_review "$workflow_root" \
      "implementer session has no identities (root=$workflow_root attempt=$attempt_number session=$canonical_session_id)" \
      "$session_context"
  [[ $session_template == fixture/gc.implementer ]] ||
    abort_failed_review "$workflow_root" \
      "implementer session template mismatch (root=$workflow_root attempt=$attempt_number session=$canonical_session_id actual=$session_template)" \
      "$session_context"

  if run_until_deadline "$retirement_deadline" "$active_beads_output_file" "$active_beads_err" \
    gc bd list --all --json --limit=0; then
    active_list_status=0
  else
    active_list_status=$?
    active_beads_json=$(<"$active_beads_output_file")
    active_list_diag=
    [[ -n $active_beads_json ]] &&
      active_list_diag=$(tr '\n' ' ' <<<"$active_beads_json")
    [[ -s $active_beads_err ]] &&
      active_list_diag+=" $(tr '\n' ' ' <"$active_beads_err")"
    abort_failed_review "$workflow_root" \
      "cannot inspect active fixture work for implementer session (root=$workflow_root attempt=$attempt_number session=$canonical_session_id exit=$active_list_status${active_list_diag:+; diagnostic=$active_list_diag})" \
      "$session_context"
  fi
  active_beads_json=$(<"$active_beads_output_file")

  active_count=$(jq -er \
    --arg root "$workflow_root" \
    --arg template fixture/gc.implementer \
    --arg template_short "gc.implementer" \
    --arg control_id "$control_id" \
    --argjson identities "$resolved_identities_json" '
    def normalize: sub("^s-"; "");
    def identity_matches($value; $identity):
      if ($value | type) != "string" or ($value | length) == 0 or
         ($identity | type) != "string" or ($identity | length) == 0 then
        false
      else
        ($value == $identity) or
        (($value | normalize) == ($identity | normalize))
      end;
    def identity_matches_any($value):
      any($identities[]; identity_matches($value; .));
    if type != "array" or
       any(.[]; type != "object" or ((.metadata // {}) | type) != "object") then
      error("backlog listing is malformed")
    else
      [.[] | select(
        ((.metadata // {})["gc.kind"] // "") != "workflow" and
        ((.metadata // {})["gc.kind"] // "") != "ralph" and
        ((.metadata // {})["gc.kind"] // "") != "spec" and
        ((.metadata // {})["gc.kind"] // "") != "workflow-finalize" and
        (.status == "in_progress" or (.status == "open" and (.assignee // "") != "")) and
        (
          identity_matches_any(.assignee) or
          identity_matches_any((.metadata // {})["gc.session_name"]) or
          (
            ((.id // "") != $control_id) and
            ((.metadata // {})["gc.root_bead_id"] // "") == $root and
            (
              ((.metadata // {})["gc.routed_to"] // "") == $template or
              ((.metadata // {})["gc.routed_to"] // "") == $template_short or
              ((.metadata // {})["gc.run_target"] // "") == $template or
              ((.metadata // {})["gc.run_target"] // "") == $template_short or
              ((.metadata // {})["gc.execution_routed_to"] // "") == $template or
              ((.metadata // {})["gc.execution_routed_to"] // "") == $template_short
            )
          )
        )
      )] | length
    end
  ' <<<"$active_beads_json") ||
    abort_failed_review "$workflow_root" \
      "cannot inspect active fixture work for implementer session (root=$workflow_root attempt=$attempt_number session=$canonical_session_id)" \
      "$session_context"
  ((active_count == 0)) ||
    abort_failed_review "$workflow_root" \
      "refusing to retire implementer session with active work (root=$workflow_root attempt=$attempt_number session=$canonical_session_id count=$active_count)" \
      "$session_context"
  [[ $session_resolution_state == missing || $session_resolution_state == closed ]] &&
    return 0

  close_output=
  if run_until_deadline "$retirement_deadline" "$close_output_file" "$close_err" \
    gc session close "$canonical_session_id" --json; then
    close_status=0
  else
    close_status=$?
  fi
  close_output=$(<"$close_output_file")
  close_diag=
  [[ -n $close_output ]] && close_diag=$close_output
  [[ -s $close_err ]] && close_diag+=" $(tr '\n' ' ' <"$close_err")"
  if ((close_status == 124)); then
    abort_failed_review "$workflow_root" \
      "cannot retire implementer session: command timed out (root=$workflow_root attempt=$attempt_number session=$canonical_session_id exit=$close_status${close_diag:+; diagnostic=$close_diag})" \
      "$session_context"
  elif ((close_status != 0)); then
    if [[ $close_diag != *"$canonical_session_id"* ]] ||
       [[ ! $close_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
      abort_failed_review "$workflow_root" \
        "cannot retire implementer session (root=$workflow_root attempt=$attempt_number session=$canonical_session_id exit=$close_status${close_diag:+; diagnostic=$close_diag})" \
        "$session_context"
    fi
  elif ! jq -e '
    type == "object" and
    .ok == true and
    .state == "closed"
  ' <<<"$close_output" >/dev/null 2>&1; then
    if [[ $close_diag != *"$canonical_session_id"* ]] ||
       [[ ! $close_diag =~ ([Cc]losed|[Nn]ot[[:space:]]+found) ]]; then
      abort_failed_review "$workflow_root" \
        "implementer session close returned unexpected result (root=$workflow_root attempt=$attempt_number session=$canonical_session_id)" \
        "$session_context"
    fi
  fi
  retirement_session_state=unknown
  while ((SECONDS < retirement_deadline)); do
    retirement_sessions_json=
    if run_until_deadline "$retirement_deadline" "$retirement_list_output_file" "$retirement_list_err" \
      gc session list --state all --json; then
      retirement_list_status=0
    else
      retirement_list_status=$?
    fi
    retirement_sessions_json=$(<"$retirement_list_output_file")
    if ((retirement_list_status != 0)); then
      retirement_list_diag=
      [[ -n $retirement_sessions_json ]] &&
        retirement_list_diag=$(tr '\n' ' ' <<<"$retirement_sessions_json")
      [[ -s $retirement_list_err ]] &&
        retirement_list_diag+=" $(tr '\n' ' ' <"$retirement_list_err")"
      abort_failed_review "$workflow_root" \
        "cannot confirm implementer session retirement (root=$workflow_root attempt=$attempt_number session=$canonical_session_id exit=$retirement_list_status${retirement_list_diag:+; diagnostic=$retirement_list_diag})" \
        "$session_context"
    fi

    retirement_list_diag=
    if retirement_session_state=$(jq -cer \
      --arg canonical "$canonical_session_id" \
      --argjson identities "$resolved_identities_json" '
      def normalize: sub("^s-"; "");
      def identity_matches($value; $identity):
        if ($value | type) != "string" or ($value | length) == 0 or
           ($identity | type) != "string" or ($identity | length) == 0 then
          false
        else
          ($value == $identity) or
          (($value | normalize) == ($identity | normalize))
        end;
      def identity_values:
        (.metadata // {}) as $metadata |
        [
          .id?, .session_id?, .name?, .session_name?, .alias?, .agent_name?,
          $metadata.id?, $metadata.session_id?, $metadata.name?,
          $metadata.session_name?, $metadata.alias?, $metadata.agent_name?,
          $metadata["gc.id"]?, $metadata["gc.session_id"]?,
          $metadata["gc.name"]?, $metadata["gc.session_name"]?,
          $metadata["gc.alias"]?, $metadata["gc.agent_name"]?,
          $metadata.configured_named_identity?
        ] | map(select(type == "string" and length > 0)) | unique;
      def identity_matches_any($value):
        any($identities[]; identity_matches($value; .)) or
        identity_matches($value; $canonical);
      def closed_string:
        if type == "string" then ascii_downcase == "closed" else false end;
      def terminal_closed:
        (.closed? == true) or
        ((.state? // "") | closed_string) or
        ((.status? // "") | closed_string);
      def sessions:
        if type == "array" then
          .
        elif type == "object" and (.sessions? | type) == "array" then
          .sessions
        else
          error("session listing is malformed")
        end;
      (sessions) as $sessions |
      if any($sessions[]; type != "object" or ((.metadata // {}) | type) != "object") then
        error("session listing is malformed")
      else
        [
          $sessions[] |
          . as $session |
          ($session | identity_values) as $session_identities |
          select(any($session_identities[]?; identity_matches_any(.))) |
          {session: $session, identities: $session_identities}
        ] |
        if length == 0 then
          "missing"
        elif length != 1 then
          error("implementer session identity is not unique")
        elif (.[0].session | terminal_closed) then
          "closed"
        else
          "present"
        end
      end
    ' <<<"$retirement_sessions_json" 2>"$retirement_list_err"); then
      :
    else
      retirement_list_status=$?
      [[ -n $retirement_sessions_json ]] &&
        retirement_list_diag=$(tr '\n' ' ' <<<"$retirement_sessions_json")
      [[ -s $retirement_list_err ]] &&
        retirement_list_diag+=" $(tr '\n' ' ' <"$retirement_list_err")"
      abort_failed_review "$workflow_root" \
        "cannot resolve implementer session retirement state (root=$workflow_root attempt=$attempt_number session=$canonical_session_id exit=$retirement_list_status${retirement_list_diag:+; diagnostic=$retirement_list_diag})" \
        "$session_context"
    fi

    [[ $retirement_session_state == missing || $retirement_session_state == closed ]] &&
      return 0
    retirement_remaining=$((retirement_deadline - SECONDS))
    ((retirement_remaining > 0)) || break
    retirement_sleep=$retirement_poll
    ((retirement_sleep > retirement_remaining)) && retirement_sleep=$retirement_remaining
    sleep "$retirement_sleep"
  done
  abort_failed_review "$workflow_root" \
    "implementer session retirement was not observable within ${retirement_timeout}s (root=$workflow_root attempt=$attempt_number session=$canonical_session_id state=$retirement_session_state; poll=${retirement_poll}s)" \
    "$session_context"
}
finalize_failed_review() {
  local workflow_root=$1 failure_reason=$2
  local beads_json control_json control_id max_attempts
  local control_deadline control_list_status control_list_diag exhaustion_deadline
  local finalization_context="attempt=$attempt"
  local control_list_output_file="$tmp_dir/finalize-review-control-list.out"
  local control_list_err="$tmp_dir/finalize-review-control-list.err"
  local exhaustion_output_file="$tmp_dir/finalize-review-exhaustion.out"
  local exhaustion_err="$tmp_dir/finalize-review-exhaustion.err"

  printf 'review-check: finalizing failed review: %s\n' "$failure_reason" >&2
  control_deadline=$((script_deadline - 360))
  if run_until_deadline "$control_deadline" "$control_list_output_file" "$control_list_err" \
    gc bd list --all --json --limit=0; then
    control_list_status=0
  else
    control_list_status=$?
    beads_json=$(<"$control_list_output_file")
    control_list_diag=
    [[ -n $beads_json ]] &&
      control_list_diag=$(tr '\n' ' ' <<<"$beads_json")
    [[ -s $control_list_err ]] &&
      control_list_diag+=" $(tr '\n' ' ' <"$control_list_err")"
    abort_failed_review "$workflow_root" \
      "cannot inspect repair controls (root=$workflow_root attempt=$attempt exit=$control_list_status${control_list_diag:+; diagnostic=$control_list_diag})" \
      "$finalization_context"
  fi
  beads_json=$(<"$control_list_output_file")
  control_json=$(jq -cer --arg root "$workflow_root" '
    def partial_retry:
      ((.metadata // {})["gc.partial_retry"] // false) as $partial |
      ($partial == true or
        (($partial | type) == "string" and ($partial | ascii_downcase) == "true"));
    def implement_step:
      (((.metadata // {})["gc.step_id"] // "") == "implement") or
      (((.metadata // {})["gc.step"] // "") == "implement") or
      (((.metadata // {})["gc.step_ref"] // "") | endswith(".implement"));
    if type != "array" or
       any(.[]; type != "object" or ((.metadata // {}) | type) != "object") then
      error("backlog listing is malformed")
    else
      [.[] |
        select(
          (.status == "in_progress" or .status == "open") and
          ((.metadata // {})["gc.root_bead_id"] // "") == $root and
          ((.metadata // {})["gc.kind"] // "") == "ralph" and
          implement_step and
          (partial_retry | not)
        )
      ] |
      if length != 1 then
        error("expected exactly one active non-discarded Ralph implement control")
      else
        {
          id: (.[0].id // ""),
          max_attempts: ((.[0].metadata["gc.max_attempts"] // null) | tostring)
        }
      end
    end
  ' <<<"$beads_json") ||
    abort_failed_review "$workflow_root" \
      "cannot identify exactly one active Ralph implement control (root=$workflow_root attempt=$attempt)" \
      "$finalization_context"
  max_attempts=$(jq -er '.max_attempts' <<<"$control_json") ||
    abort_failed_review "$workflow_root" \
      "Ralph implement control has no gc.max_attempts (root=$workflow_root attempt=$attempt)" \
      "$finalization_context"
  [[ $max_attempts =~ ^[1-9][0-9]*$ ]] ||
    abort_failed_review "$workflow_root" \
      "invalid compiled Ralph gc.max_attempts: $max_attempts (root=$workflow_root)" \
      "$finalization_context"
  control_id=$(jq -er '.id | select(type == "string" and length > 0)' <<<"$control_json") ||
    abort_failed_review "$workflow_root" \
      "Ralph implement control has no ID (root=$workflow_root attempt=$attempt)" \
      "$finalization_context"
  finalization_context+=" control=$control_id"

  if ((attempt >= max_attempts)); then
    exhaustion_deadline=$((script_deadline - 60))
    run_until_deadline "$exhaustion_deadline" "$exhaustion_output_file" "$exhaustion_err" \
      gc bd update "$workflow_root" \
      --set-metadata gc.outcome=fail \
      --set-metadata gc.failure_class=review_attempts_exhausted \
      --set-metadata "gc.failure_reason=review failed after $attempt of $max_attempts allowed attempts" \
      --set-metadata "gc.exhausted_attempts=$attempt" ||
      abort_failed_review "$workflow_root" \
        "cannot record review exhaustion on workflow root: $workflow_root" \
        "$finalization_context"
  else
    retire_failed_implementer_session "$workflow_root" "$attempt" "$beads_json" "$control_id"
  fi
  exit 1
}







preflight_failure=
if ! prepare_review_context; then
  abort_failed_review "${WORK_ROOT##*/}" \
    "$preflight_failure" \
    "attempt=${attempt:-unknown}"
fi

input_failure=
if ! build_review_input; then
  abort_failed_review "${WORK_ROOT##*/}" \
    "$input_failure" \
    "attempt=$attempt"
fi

reviewer_status=1
for reviewer_try in 1 2 3; do
  : >"$raw_output"
  : >"$raw_error"
  reviewer_deadline=$((SECONDS + reviewer_timeout))
  ((reviewer_deadline > script_deadline)) && reviewer_deadline=$script_deadline
  if (
    unset CLAUDE_CONFIG_DIR
    run_until_deadline "$reviewer_deadline" "$raw_output" "$raw_error" \
      env HOME="$reviewer_home" "$reviewer" --safe-mode \
      --no-session-persistence --tools '' -p --output-format json \
      --json-schema "$schema" <"$input"
  ); then
    reviewer_status=0
    break
  else
    reviewer_status=$?
  fi
  if ((reviewer_try < 3)); then
    cat "$raw_error" >&2
    cat "$raw_output" >&2
    printf 'review-check: primary reviewer failed; retrying (%s/3)\n' "$reviewer_try" >&2
    retry_sleep=$((reviewer_try * 5))
    retry_remaining=$((script_deadline - SECONDS))
    ((retry_remaining > 0)) || break
    ((retry_sleep > retry_remaining)) && retry_sleep=$retry_remaining
    sleep "$retry_sleep"
  fi
done
if ((reviewer_status != 0)); then
  omp_reviewer=$reviewer_home/.local/share/mise/installs/github-can1357-oh-my-pi/latest/omp
  omp_output=$tmp_dir/reviewer.txt
  omp_error=$tmp_dir/reviewer.err
  omp_failure=
  omp_deadline=$((SECONDS + 180))
  ((omp_deadline > script_deadline - 360)) &&
    omp_deadline=$((script_deadline - 360))
  if run_until_deadline "$omp_deadline" "$omp_output" "$omp_error" \
    env HOME="$reviewer_home" "$omp_reviewer" --mode text -p --no-session --no-tools \
    --no-extensions --no-skills --no-rules --max-time 3m \
    --system-prompt 'Review the supplied plan, acceptance criteria, diff, and report. Return only JSON matching {"verdict":"pass|fail","findings":["actionable finding"]}.' \
    "@$input"; then
    omp_status=0
  else
    omp_status=$?
  fi
  if ((omp_status != 0)); then
    omp_failure="OMP reviewer fallback failed (exit=$omp_status)"
    if [[ -s $omp_error ]]; then
      omp_failure+=": $(tr '\n' ' ' <"$omp_error")"
    fi
  elif [[ ! -s $omp_output ]]; then
    omp_failure="OMP reviewer fallback returned no output"
  elif ! jq -Rse '
    def parsed: try fromjson catch empty;
    . as $raw |
    [
      ($raw | parsed),
      ($raw | split("\n")[] | parsed),
      (try ($raw | capture("```(?:json)?[[:space:]]*(?<payload>.*?)[[:space:]]*```"; "is").payload | parsed) catch empty)
    ] |
    map(select(type == "object" and has("verdict") and has("findings"))) |
    last
  ' "$omp_output" >"$raw_output"; then
    omp_failure="OMP reviewer fallback did not contain a JSON verdict"
  elif ! jq -e 'type == "object" and has("verdict") and has("findings")' "$raw_output" >/dev/null; then
    omp_failure="OMP reviewer fallback did not contain a JSON verdict"
  fi
  if [[ -n $omp_failure ]]; then
    persist_reviewer_failure "$omp_reviewer" "$omp_failure"
  fi
  reviewer="$omp_reviewer"
fi

structured=$(jq -cer '
  if type == "object" and (.structured_output? != null) then .structured_output
  elif type == "object" and (.result? != null) and (.result | type == "string") then
    (try (.result | fromjson) catch .)
  else .
  end
' "$raw_output") || {
  cat "$raw_output" >&2
  persist_reviewer_failure "$reviewer" 'reviewer did not return JSON'
}

jq -e 'type == "object" and (keys == ["findings", "verdict"]) and (.verdict == "pass" or .verdict == "fail") and (.findings | type == "array" and all(.[]; type == "string"))' \
  <<<"$structured" >/dev/null || {
  printf '%s\n' "$structured" >&2
  persist_reviewer_failure "$reviewer" 'reviewer JSON did not match the verdict schema'
}

provider_verdict=$(jq -r '.verdict' <<<"$structured") ||
  abort_failed_review "${WORK_ROOT##*/}" \
    "cannot read reviewer verdict" \
    "attempt=$attempt"
findings=$(jq -c '.findings' <<<"$structured") ||
  abort_failed_review "${WORK_ROOT##*/}" \
    "cannot read reviewer findings" \
    "attempt=$attempt"

if ((attempt == 1)) && fixture_fail_once_requested; then
  provider_verdict=fail
  findings=$(jq -c '. + ["Fixture fail-once gate: the first review attempt is intentionally rejected; use this finding on the fresh repair iteration."]' <<<"$findings") ||
    abort_failed_review "${WORK_ROOT##*/}" \
      "cannot encode fixture fail-once finding" \
      "attempt=$attempt"
fi

write_verdict_artifacts ||
  abort_failed_review "${WORK_ROOT##*/}" \
    "cannot persist reviewer verdict artifacts" \
    "attempt=$attempt"

if [[ $provider_verdict == fail ]]; then
  printf 'review-check: attempt %s %s (%s)\n' "$attempt" "$provider_verdict" "${input#"$REPO_ROOT"/}"
  finalize_failed_review "${WORK_ROOT##*/}" 'reviewer returned a structured fail verdict'
fi

printf 'review-check: attempt %s %s (%s)\n' "$attempt" "$provider_verdict" "${input#"$REPO_ROOT"/}"
if [[ $provider_verdict == pass ]]; then
  exit 0
fi
exit 1
