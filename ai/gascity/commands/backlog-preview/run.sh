#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "usage: $0" >&2
  exit 2
fi
source_path=${GC_BACKLOG_SOURCE:-backlog.md}
root=$(cd "$(dirname "$0")/../.." && pwd)
args=(backlog preview --source "$source_path")
if [[ -n ${GC_BACKLOG_RELATIVE_PATH:-} ]]; then
  args+=(--relative-path "$GC_BACKLOG_RELATIVE_PATH")
fi
exec uv run --project "$root/sidecar" gascity-sidecar "${args[@]}"
