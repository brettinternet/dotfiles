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
elif [[ -z $WORK_ROOT ]]; then
  work_base="$REPO_ROOT/.gascity/work"
  [[ -d $work_base ]] || fail "missing workflow directory: $work_base"
  latest_mtime=-1
  latest_plan=
  while IFS= read -r -d '' plan_path; do
    plan_mtime=$(stat -f '%m' "$plan_path")
    if ((plan_mtime > latest_mtime)); then
      latest_mtime=$plan_mtime
      latest_plan=$plan_path
    fi
  done < <(find "$work_base" -mindepth 2 -maxdepth 2 -type f -name plan.md -print0)
  [[ -n $latest_plan ]] || fail "no durable workflow plan found below $work_base"
  WORK_ROOT=${latest_plan%/plan.md}
fi

[[ -d $WORK_ROOT ]] || fail "missing workflow root: $WORK_ROOT"
PLAN=$WORK_ROOT/plan.md
[[ -f $PLAN ]] || fail "missing plan: $PLAN"

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

attempt_dir=${report%/report.md}
input=$attempt_dir/reviewer-input.md
verdict_file=$attempt_dir/verdict.json
review_file=$attempt_dir/review.md

repo_diff=$(git -C "$REPO_ROOT" diff --no-ext-diff)
if [[ -z $repo_diff ]]; then
  repo_diff=$(git -C "$REPO_ROOT" show --format=fuller --no-ext-diff --stat --patch HEAD)
fi

{
  printf '# Review input\n\n'
  printf 'This input is limited to the current plan, its acceptance criteria, the current repository diff, and the latest implementer report. Do not inspect prior reports, transcripts, or other workflow artifacts.\n\n'
  printf '## Plan and acceptance criteria\n\n'
  cat "$PLAN"
  printf '\n## Current repository diff\n\n```diff\n%s\n```\n' "$repo_diff"
  printf '\n## Latest implementer report (attempt %s)\n\n' "$attempt"
  cat "$report"
} >"$input"

schema='{"type":"object","additionalProperties":false,"properties":{"verdict":{"type":"string","enum":["pass","fail"]},"findings":{"type":"array","items":{"type":"string"}}},"required":["verdict","findings"]}'
review_prompt=$(cat "$input")
reviewer=${GC_REVIEW_CHECK_CLAUDE:-claude}
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gc-review-check.XXXXXX")
trap 'trash "$tmp_dir" 2>/dev/null || true' EXIT
raw_output=$tmp_dir/reviewer.json
raw_error=$tmp_dir/reviewer.err

if ! (cd "$REPO_ROOT" && "$reviewer" --bare --no-session-persistence --tools '' -p \
  --output-format json --json-schema "$schema" "$review_prompt" >"$raw_output" 2>"$raw_error"); then
  cat "$raw_error" >&2
  fail "reviewer command failed"
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

jq -e 'type == "object" and (.verdict == "pass" or .verdict == "fail") and (.findings | type == "array")' \
  <<<"$structured" >/dev/null || {
  printf '%s\n' "$structured" >&2
  fail 'reviewer JSON did not match the verdict schema'
}

provider_verdict=$(jq -r '.verdict' <<<"$structured")
findings=$(jq -c '.findings' <<<"$structured")

if grep -Fq 'fixture:fail-once' "$PLAN" && ((attempt == 1)); then
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

printf 'review-check: attempt %s %s (%s)\n' "$attempt" "$provider_verdict" "${input#"$REPO_ROOT"/}"
if [[ $provider_verdict == pass ]]; then
  exit 0
fi
exit 1
