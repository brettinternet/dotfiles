#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  printf 'usage: dispatch.sh navigate|focus|resize left|down|up|right forwarded-key\n' >&2
  exit 2
fi

mode=$1
direction=$2
forwarded_key=$3
case "$direction" in
  left) direction_key=h ;;
  down) direction_key=j ;;
  up) direction_key=k ;;
  right) direction_key=l ;;
  *) printf 'unknown direction: %s\n' "$direction" >&2; exit 2 ;;
esac
herdr_bin=${HERDR_BIN_PATH:-herdr}
pane_id=${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}

if [ -z "$pane_id" ]; then
  pane_id=$($herdr_bin pane current --current 2>/dev/null | jq -r '.result.pane.pane_id // empty')
fi
[ -n "$pane_id" ] || { printf 'could not determine the active Herdr pane\n' >&2; exit 1; }

if [ "$mode" = focus ]; then
  exec "$herdr_bin" pane focus --direction "$direction" --pane "$pane_id"
fi

process_name=$($herdr_bin pane process-info --pane "$pane_id" 2>/dev/null | jq -r '.result.process_info.foreground_processes[0].name // empty')
case "$process_name" in
  nvim|vim|view|lvim|nvim-*)
    if [ "$mode" = navigate ]; then
      exec "$herdr_bin" pane send-keys "$pane_id" "$forwarded_key"
    fi
    ;;
  tmux|tmate)
    case "$mode" in
      navigate) exec "$herdr_bin" pane send-keys "$pane_id" ctrl+a "$direction_key" ;;
      resize) exec "$herdr_bin" pane send-keys "$pane_id" ctrl+a "alt+$direction_key" ;;
    esac
    ;;
esac

case "$mode" in
  navigate) exec "$herdr_bin" pane focus --direction "$direction" --pane "$pane_id" ;;
  resize) exec "$herdr_bin" pane resize --direction "$direction" --pane "$pane_id" ;;
  *) printf 'unknown mode: %s\n' "$mode" >&2; exit 2 ;;
esac
