#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 TASK_ID" >&2
  exit 2
fi
source_path=${GC_BACKLOG_SOURCE:-backlog.md}
root=$(cd "$(dirname "$0")/../.." && pwd)
args=(backlog import --source "$source_path" "$1")
if [[ -n ${GC_BACKLOG_RELATIVE_PATH:-} ]]; then
  args+=(--relative-path "$GC_BACKLOG_RELATIVE_PATH")
fi
exec uv run --project "$root/sidecar" gascity-sidecar "${args[@]}"
