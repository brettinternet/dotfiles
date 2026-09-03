#!/bin/sh
set -eu

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
history_file="$state_dir/previous-pane-focus.history"
[ -f "$history_file" ] || exit 0

closed_id="${HERDR_PANE_ID:-}"
[ -n "$closed_id" ] || exit 0

herdr_bin="${HERDR_BIN_PATH:-herdr}"
open_panes="$("$herdr_bin" pane list 2>/dev/null || true)"
[ -n "$open_panes" ] || exit 0

# Walk upward through focus history from the closed pane. Ignore panes from
# other tabs and panes that have since closed, then restore the nearest match.
open_ids="$(printf '%s\n' "$open_panes" | jq -r '.result.panes[].pane_id' 2>/dev/null | tr '\n' ' ' || true)"
target="$(awk -F '\t' -v closed="$closed_id" -v open="$open_ids" '
  BEGIN {
    count = split(open, ids, " ")
    for (i = 1; i <= count; i++) is_open[ids[i]] = 1
  }
  NF == 2 {
    tabs[NR] = $1
    panes[NR] = $2
  }
  END {
    last_closed = 0
    for (i = NR; i >= 1; i--) {
      if (panes[i] == closed) { last_closed = i; closed_tab = tabs[i]; break }
    }
    if (last_closed == 0) exit
    for (i = last_closed - 1; i >= 1; i--) {
      if (tabs[i] == closed_tab && panes[i] != closed && is_open[panes[i]]) {
        print panes[i]
        exit
      }
    }
  }
' "$history_file")"

[ -n "$target" ] || exit 0

# Only agent panes can be focused by pane id today; plain shell panes retain
# Herdr's default focus selection.
"$herdr_bin" agent focus "$target" >/dev/null 2>&1 || true
