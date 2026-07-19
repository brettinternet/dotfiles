#!/bin/sh
set -eu

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

uv_bin="${GC_SIDECAR_UV_BIN:-}"
if [ -z "$uv_bin" ]; then
  uv_bin="$(command -v uv 2>/dev/null || true)"
fi
if [ -z "$uv_bin" ]; then
  printf '%s\n' "uv not found; set GC_SIDECAR_UV_BIN in $ROOT/.env" >&2
  exit 127
fi
exec "$uv_bin" run --project "$ROOT/sidecar" gascity-sidecar serve
