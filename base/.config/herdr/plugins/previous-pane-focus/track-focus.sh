#!/bin/sh
set -eu

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
mkdir -p "$state_dir"
history_file="$state_dir/previous-pane-focus.history"

pane_id="${HERDR_PANE_ID:-}"
tab_id="${HERDR_TAB_ID:-}"
[ -n "$pane_id" ] && [ -n "$tab_id" ] || exit 0

entry="$(printf '%s\t%s' "$tab_id" "$pane_id")"

# Append, skipping consecutive duplicates so re-focusing the same pane
# doesn't pad the history.
last_line="$(tail -n 1 "$history_file" 2>/dev/null || true)"
if [ "$last_line" != "$entry" ]; then
  printf '%s\n' "$entry" >> "$history_file"
  # Keep the file bounded.
  tail -n 200 "$history_file" > "$history_file.tmp" 2>/dev/null && mv "$history_file.tmp" "$history_file"
fi
