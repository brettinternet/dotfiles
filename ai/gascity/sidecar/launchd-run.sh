#!/bin/sh
set -eu

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

exec uv run --project "$ROOT/sidecar" gascity-sidecar serve
