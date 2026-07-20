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

repo_diff=$(git -C "$REPO_ROOT" diff --no-ext-diff HEAD -- .)
untracked_diff=
while IFS= read -r -d '' untracked_path; do
  case $untracked_path in
    .gascity|.gascity/*|.omp|.omp/*|.local/fixture-rig/.omp|.local/fixture-rig/.omp/*) continue ;;
  esac
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
if [[ -z $repo_diff ]]; then
  repo_diff=$(git -C "$REPO_ROOT" show --format=fuller --no-ext-diff --stat --patch HEAD)
fi

{
  printf '# Review input\n\n'
  printf 'This input is limited to the current plan, its acceptance criteria, the current repository diff (including non-ignored untracked files), and the latest implementer report. Do not inspect prior reports, transcripts, or other workflow artifacts.\n\n'
  printf '## Plan and acceptance criteria\n\n'
  cat "$PLAN"
  printf '\n## Current repository diff\n\n```diff\n%s\n```\n' "$repo_diff"
  printf '\n## Latest implementer report (attempt %s)\n\n' "$attempt"
  cat "$report"
} >"$input"

schema='{"type":"object","additionalProperties":false,"properties":{"verdict":{"type":"string","enum":["pass","fail"]},"findings":{"type":"array","items":{"type":"string"}}},"required":["verdict","findings"]}'
reviewer=${GC_REVIEW_CHECK_CLAUDE:-claude}
reviewer_home=${HOME:-}
if [[ $reviewer == claude ]] && ! command -v "$reviewer" >/dev/null 2>&1; then
  mise_claude=${MISE_DATA_DIR:-$reviewer_home/.local/share/mise}/installs/claude/latest/claude
  local_claude=$reviewer_home/.local/bin/claude
  if [[ ! -x $mise_claude && ! -x $local_claude ]]; then
    user_name=$(id -un)
    [[ $user_name =~ ^[a-zA-Z0-9._-]+$ ]] || fail "invalid runtime user: $user_name"
    eval "reviewer_home=~$user_name"
    mise_claude=$reviewer_home/.local/share/mise/installs/claude/latest/claude
    local_claude=$reviewer_home/.local/bin/claude
  fi
  if [[ -x $mise_claude ]]; then
    reviewer=$mise_claude
  elif [[ -x $local_claude ]]; then
    reviewer=$local_claude
  fi
fi
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gc-review-check.XXXXXX")
trap 'trash "$tmp_dir" 2>/dev/null || true' EXIT
raw_output=$tmp_dir/reviewer.json
raw_error=$tmp_dir/reviewer.err

reviewer_status=0
(
  cd "$REPO_ROOT"
  unset CLAUDE_CONFIG_DIR
  HOME=$reviewer_home "$reviewer" --safe-mode --no-session-persistence --tools '' -p \
    --output-format json --json-schema "$schema" <"$input" >"$raw_output" 2>"$raw_error"
) || reviewer_status=$?
if ((reviewer_status != 0)); then
  cat "$raw_error" >&2
  cat "$raw_output" >&2
  omp_reviewer=$reviewer_home/.local/share/mise/installs/github-can1357-oh-my-pi/latest/omp
  [[ -x $omp_reviewer ]] || fail "reviewer command failed and OMP fallback is unavailable"
  omp_output=$tmp_dir/reviewer.jsonl
  if ! (
    cd "$REPO_ROOT"
    HOME=$reviewer_home "$omp_reviewer" --model claude --mode json -p --no-session --no-tools \
      --no-extensions --no-skills --no-rules \
      --system-prompt 'Review the supplied plan, acceptance criteria, diff, and report. Return only JSON matching {"verdict":"pass|fail","findings":["actionable finding"]}.' \
      "@$input" >"$omp_output"
  ); then
    fail "OMP reviewer fallback failed"
  fi
  jq -sce '
    [.[] |
      select(.type == "message_end" and .message.role == "assistant") |
      .message.content[] |
      select(.type == "text") |
      .text] |
    last |
    fromjson
  ' "$omp_output" >"$raw_output" || fail "OMP reviewer fallback did not return JSON"
  reviewer="$omp_reviewer --model claude"
fi

structured=$(jq -cer '
  if type == "object" and (.structured_output? != null) then .structured_output
  elif type == "object" and (.result? != null) and (.result | type == "string") then
    (try (.result | fromjson) catch .)
  else .
  end
' "$raw_output") || {
  cat "$raw_output" >&2
  fail 'reviewer did not return JSON'
}

jq -e 'type == "object" and (keys == ["findings", "verdict"]) and (.verdict == "pass" or .verdict == "fail") and (.findings | type == "array" and all(.[]; type == "string"))' \
  <<<"$structured" >/dev/null || {
  printf '%s\n' "$structured" >&2
  fail 'reviewer JSON did not match the verdict schema'
}

provider_verdict=$(jq -r '.verdict' <<<"$structured")
findings=$(jq -c '.findings' <<<"$structured")

if grep -Fq 'fixture:fail-once' "$PLAN" "$WORK_ROOT/brief.md" 2>/dev/null && ((attempt == 1)); then
  provider_verdict=fail
  findings=$(jq -c '. + ["Fixture fail-once gate: the first review attempt is intentionally rejected; use this finding on the fresh repair iteration."]' <<<"$findings")
fi

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
  printf -- '- Verdict: **%s**\n- Reviewer: `%s`\n- Input: `%s`\n\n' "$provider_verdict" "$reviewer" "${input#"$REPO_ROOT"/}"
  printf '## Findings\n\n'
  if ((${#findings} == 2)); then
    printf -- '- None.\n'
  else
    jq -r '.[] | "- " + .' <<<"$findings"
  fi
} >"$review_file"

if [[ $provider_verdict == fail ]]; then
  workflow_root=${WORK_ROOT##*/}
  root_json=$(gc bd show "$workflow_root" --json) ||
    fail "cannot read workflow root: $workflow_root"
  max_attempts=$(jq -er '
    if type == "array" then .[0].metadata["gc.var.max_repair_attempts"]
    else .metadata["gc.var.max_repair_attempts"]
    end
  ' <<<"$root_json") || fail "workflow root has no repair limit: $workflow_root"
  [[ $max_attempts =~ ^[1-9][0-9]*$ ]] ||
    fail "invalid workflow repair limit: $max_attempts"
  if ((attempt >= max_attempts)); then
    gc bd update "$workflow_root" \
      --set-metadata gc.outcome=fail \
      --set-metadata gc.failure_class=review_attempts_exhausted \
      --set-metadata "gc.failure_reason=review failed after $attempt of $max_attempts allowed attempts" \
      --set-metadata "gc.exhausted_attempts=$attempt" >/dev/null ||
      fail "cannot record review exhaustion on workflow root: $workflow_root"
  fi
fi

printf 'review-check: attempt %s %s (%s)\n' "$attempt" "$provider_verdict" "${input#"$REPO_ROOT"/}"
if [[ $provider_verdict == pass ]]; then
  exit 0
fi
exit 1
