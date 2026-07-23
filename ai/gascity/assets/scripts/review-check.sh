#!/usr/bin/env bash
# Run the implement-step reviewer and persist the bounded-loop evidence.

set -euo pipefail

fail() {
  printf 'review-check: %s\n' "$*" >&2
  exit 2
}

SCRIPT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ -n ${GC_REVIEW_CHECK_ROOT:-} ]]; then
  REPO_ROOT=$(cd -- "$GC_REVIEW_CHECK_ROOT" && pwd)
elif [[ -n ${GC_RIG:-} ]]; then
  rig_json=$(gc rig status "$GC_RIG" --json) ||
    fail "cannot inspect configured rig: $GC_RIG"
  rig_path=$(jq -er '.rig.path // .path' <<<"$rig_json") ||
    fail "configured rig has no path: $GC_RIG"
  REPO_ROOT=$(cd -- "$rig_path" && pwd)
elif [[ -n ${BEADS_DIR:-} && -d ${BEADS_DIR} ]]; then
  REPO_ROOT=$(cd -- "$BEADS_DIR/.." && pwd)
elif [[ -d "$PWD/.gascity/work" ]]; then
  REPO_ROOT=$PWD
elif [[ -d "$SCRIPT_ROOT/.gascity/work" ]]; then
  REPO_ROOT=$SCRIPT_ROOT
else
  REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || fail 'cannot locate the rig repository'
fi

WORK_ROOT=${GC_WORKFLOW_ROOT:-}
if [[ -n $WORK_ROOT && $WORK_ROOT != /* ]]; then
  WORK_ROOT="$REPO_ROOT/.gascity/work/$WORK_ROOT"
elif [[ -n ${GC_BEAD_ID:-} ]]; then
  bead_json=$(gc bd show "$GC_BEAD_ID" --json) ||
    fail "cannot read assigned bead: $GC_BEAD_ID"
  root_id=$(jq -er '
    if type == "array" then .[0].metadata["gc.root_bead_id"]
    else .metadata["gc.root_bead_id"]
    end
  ' <<<"$bead_json") || fail "assigned bead has no workflow root: $GC_BEAD_ID"
  WORK_ROOT="$REPO_ROOT/.gascity/work/$root_id"
elif [[ -z $WORK_ROOT ]]; then
  work_base="$REPO_ROOT/.gascity/work"
  [[ -d $work_base ]] || fail "missing workflow directory: $work_base"
  shopt -s nullglob
  plan_paths=("$work_base"/*/plan.md)
  shopt -u nullglob
  ((${#plan_paths[@]} == 1)) || fail "GC_WORKFLOW_ROOT or GC_BEAD_ID is required when workflow plans are ambiguous"
  WORK_ROOT=${plan_paths[0]%/plan.md}
fi

[[ -d $WORK_ROOT ]] || fail "missing workflow root: $WORK_ROOT"

PLAN=$WORK_ROOT/plan.md
[[ -f $PLAN ]] || fail "missing plan: $PLAN"

attempt=${GC_ITERATION:-${GC_ATTEMPT:-}}
if [[ -n $attempt ]]; then
  [[ $attempt =~ ^[0-9]+$ ]] || fail "invalid review iteration: $attempt"
  report="$WORK_ROOT/attempts/$attempt/report.md"
  [[ -f $report ]] || fail "missing implementer report for iteration $attempt"
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
  ((attempt >= 1)) || fail "no implementer report found below $WORK_ROOT/attempts"
fi

attempt_dir=${report%/report.md}
input=$attempt_dir/reviewer-input.md
verdict_file=$attempt_dir/verdict.json
review_file=$attempt_dir/review.md

changed_files=()
while IFS= read -r -d '' tracked_path; do
  case $tracked_path in
    .gascity|.gascity/*|.omp|.omp/*|.local/fixture-rig/.omp|.local/fixture-rig/.omp/*) continue ;;
  esac
  changed_files+=("$tracked_path")
done < <(git -C "$REPO_ROOT" diff --name-only -z HEAD --)

repo_diff=$(git -C "$REPO_ROOT" diff --no-ext-diff HEAD -- .)
untracked_diff=
while IFS= read -r -d '' untracked_path; do
  case $untracked_path in
    .gascity|.gascity/*|.omp|.omp/*|.local/fixture-rig/.omp|.local/fixture-rig/.omp/*) continue ;;
  esac
  changed_files+=("$untracked_path")
  untracked_output=
  if untracked_output=$(git -C "$REPO_ROOT" diff --no-ext-diff --no-index /dev/null "$REPO_ROOT/$untracked_path"); then
    :
  else
    diff_status=$?
    ((diff_status == 1)) || fail "cannot read untracked diff: $untracked_path"
  fi
  untracked_diff+=$untracked_output
  untracked_diff+=$'\n'
done < <(git -C "$REPO_ROOT" ls-files --others --exclude-standard -z)
if [[ -n $repo_diff && -n $untracked_diff ]]; then
  repo_diff+=$'\n'
fi
repo_diff+=$untracked_diff
[[ -n $repo_diff ]] ||
  fail 'implementation produced no uncommitted repository diff for review'
report_files_lines=$(grep -E \
  '^[[:space:]]*-[[:space:]]+Files changed:' \
  "$report" || true)
[[ -n $report_files_lines ]] ||
  fail 'implementer report is missing its "- Files changed: <JSON array>" field'
(( $(grep -Ec \
  '^[[:space:]]*-[[:space:]]+Files changed:' \
  "$report") == 1 )) ||
  fail 'implementer report must contain exactly one "- Files changed: <JSON array>" field'
report_files_json=${report_files_lines#*:}
report_files_json=${report_files_json#"${report_files_json%%[![:space:]]*}"}
derived_changed_files_json=$(printf '%s\0' "${changed_files[@]}" |
  jq -Rsc 'split("\u0000") | map(select(length > 0)) | sort | unique')
jq -e --argjson expected "$derived_changed_files_json" '
  type == "array" and
  all(.[]; type == "string" and length > 0) and
  . == $expected
' <<<"$report_files_json" >/dev/null 2>&1 ||
  fail "implementer report changed-file set does not match repository diff: expected $derived_changed_files_json"


{
  printf '# Review input\n\n'
  printf 'This input is limited to the current plan, its acceptance criteria, the current repository diff (including non-ignored untracked files), and the latest implementer report. Do not inspect prior reports, transcripts, or other workflow artifacts.\n\n'
  printf '## Plan and acceptance criteria\n\n'
  cat "$PLAN"
  # shellcheck disable=SC2016
  printf '\n## Current repository diff\n\n```diff\n%s\n```\n' "$repo_diff"
  printf '\n## Latest implementer report (attempt %s)\n\n' "$attempt"
  cat "$report"
} >"$input"

schema='{"type":"object","additionalProperties":false,"properties":{"verdict":{"type":"string","enum":["pass","fail"]},"findings":{"type":"array","items":{"type":"string"}}},"required":["verdict","findings"]}'
reviewer=${GC_REVIEW_CHECK_CLAUDE:-claude}
user_name=$(id -un)
[[ $user_name =~ ^[a-zA-Z0-9._-]+$ ]] || fail "invalid runtime user: $user_name"
eval "reviewer_home=~$user_name"
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
  fail "invalid Claude reviewer timeout: $reviewer_timeout (expected 1-90 seconds)"
fi
timeout_cmd=$(command -v timeout || true)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gc-review-check.XXXXXX")
trap 'trash "$tmp_dir" 2>/dev/null || true' EXIT
raw_output=$tmp_dir/reviewer.json
raw_error=$tmp_dir/reviewer.err
write_verdict_artifacts() {
  jq -n \
    --arg workflow_root "${WORK_ROOT##*/}" \
    --argjson attempt "$attempt" \
    --arg verdict "$provider_verdict" \
    --arg reviewer "$reviewer" \
    --arg input "${input#"$REPO_ROOT"/}" \
    --argjson findings "$findings" \
    '{workflow_root:$workflow_root,attempt:$attempt,verdict:$verdict,reviewer:$reviewer,input:$input,findings:$findings}' \
    >"$verdict_file"

  {
    printf '# Review attempt %s\n\n' "$attempt"
    # shellcheck disable=SC2016
    printf -- '- Verdict: **%s**\n- Reviewer: `%s`\n- Input: `%s`\n\n' "$provider_verdict" "$reviewer" "${input#"$REPO_ROOT"/}"
    printf '## Findings\n\n'
    if ((${#findings} == 2)); then
      printf -- '- None.\n'
    else
      jq -r '.[] | "- " + .' <<<"$findings"
    fi
  } >"$review_file"
}

persist_reviewer_failure() {
  local reviewer_label=$1 message=$2
  reviewer=$reviewer_label
  provider_verdict=fail
  findings=$(jq -nc --arg finding "$message" '[$finding]')
  write_verdict_artifacts
  fail "$message"
}

fixture_fail_once_requested() {
  grep -Fq 'fixture:fail-once' "$PLAN" "$WORK_ROOT/brief.md" 2>/dev/null &&
    return 0

  local workflow_root root_json source_id source_json source_text
  workflow_root=${WORK_ROOT##*/}
  root_json=$(cd "$REPO_ROOT" && gc bd show "$workflow_root" --json 2>/dev/null) || return 1
  source_id=$(jq -er '
    if type == "array" then .[0].metadata["gc.var.item"]
    else .metadata["gc.var.item"]
    end
  ' <<<"$root_json") || return 1
  source_json=$(cd "$REPO_ROOT" && gc bd show "$source_id" --json 2>/dev/null) || return 1
  source_text=$(jq -er '
    if type == "array" then .[0] else . end |
    [.title, .description] |
    map(. // "") |
    join("\n")
  ' <<<"$source_json") || return 1
  [[ $source_text == *'fixture:fail-once'* ]]
}




reviewer_status=1
if [[ -z $timeout_cmd ]]; then
  reviewer_status=127
  printf 'review-check: timeout command unavailable; skipping primary reviewer\n' >&2
else
  for reviewer_try in 1 2 3; do
    : >"$raw_output"
    : >"$raw_error"
    if (
      cd "$REPO_ROOT"
      unset CLAUDE_CONFIG_DIR
      "$timeout_cmd" --foreground --kill-after=5s "${reviewer_timeout}s" \
        env HOME="$reviewer_home" "$reviewer" --safe-mode \
        --no-session-persistence --tools '' -p --output-format json \
        --json-schema "$schema" <"$input" >"$raw_output" 2>"$raw_error"
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
      sleep $((reviewer_try * 5))
    fi
  done
fi
if ((reviewer_status != 0)); then
  omp_reviewer=$reviewer_home/.local/share/mise/installs/github-can1357-oh-my-pi/latest/omp
  omp_output=$tmp_dir/reviewer.txt
  omp_failure=
  if ! (
    cd "$REPO_ROOT"
    HOME=$reviewer_home "$omp_reviewer" --mode text -p --no-session --no-tools \
      --no-extensions --no-skills --no-rules --max-time 3m \
      --system-prompt 'Review the supplied plan, acceptance criteria, diff, and report. Return only JSON matching {"verdict":"pass|fail","findings":["actionable finding"]}.' \
      "@$input" >"$omp_output"
  ); then
    omp_failure="OMP reviewer fallback failed"
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

provider_verdict=$(jq -r '.verdict' <<<"$structured")
findings=$(jq -c '.findings' <<<"$structured")

if ((attempt == 1)) && fixture_fail_once_requested; then
  provider_verdict=fail
  findings=$(jq -c '. + ["Fixture fail-once gate: the first review attempt is intentionally rejected; use this finding on the fresh repair iteration."]' <<<"$findings")
fi

write_verdict_artifacts

if [[ $provider_verdict == fail ]]; then
  workflow_root=${WORK_ROOT##*/}
  root_json=$(cd "$REPO_ROOT" && gc bd show "$workflow_root" --json) ||
    fail "cannot read workflow root: $workflow_root"
  max_attempts=$(jq -er '
    if type == "array" then .[0].metadata["gc.var.max_repair_attempts"]
    else .metadata["gc.var.max_repair_attempts"]
    end
  ' <<<"$root_json") || fail "workflow root has no repair limit: $workflow_root"
  [[ $max_attempts =~ ^[1-9][0-9]*$ ]] ||
    fail "invalid workflow repair limit: $max_attempts"
  if ((attempt >= max_attempts)); then
    (
      cd "$REPO_ROOT"
      gc bd update "$workflow_root" \
        --set-metadata gc.outcome=fail \
        --set-metadata gc.failure_class=review_attempts_exhausted \
        --set-metadata "gc.failure_reason=review failed after $attempt of $max_attempts allowed attempts" \
        --set-metadata "gc.exhausted_attempts=$attempt" >/dev/null
    ) || fail "cannot record review exhaustion on workflow root: $workflow_root"
  fi
fi

printf 'review-check: attempt %s %s (%s)\n' "$attempt" "$provider_verdict" "${input#"$REPO_ROOT"/}"
if [[ $provider_verdict == pass ]]; then
  exit 0
fi
exit 1
