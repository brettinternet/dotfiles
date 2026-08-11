#!/bin/sh
set -eu

snapshot="$(herdr api snapshot)"
title="$(printf '%s\n' "$snapshot" | jq -r '
  .result.snapshot as $snapshot
  | $snapshot.panes[]
  | select(.pane_id == $snapshot.focused_pane_id)
  | .terminal_title_stripped // .terminal_title // empty
')"

if [ -n "$title" ]; then
  herdr terminal title set "$title" >/dev/null
else
  herdr terminal title clear >/dev/null
fi
