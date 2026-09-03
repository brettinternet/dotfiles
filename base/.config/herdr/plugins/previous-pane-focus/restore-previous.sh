#!/bin/sh
set -eu

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
history_file="$state_dir/previous-pane-focus.history"
[ -f "$history_file" ] || exit 0

closed_id="${HERDR_PANE_ID:-}"
closed_tab="${HERDR_TAB_ID:-}"
[ -n "$closed_id" ] && [ -n "$closed_tab" ] || exit 0

herdr_bin="${HERDR_BIN_PATH:-herdr}"
open_panes="$("$herdr_bin" pane list 2>/dev/null || true)"
[ -n "$open_panes" ] || exit 0

# Walk upward through focus history from the closed pane. Use current pane
# membership so panes moved to other tabs are ignored along with closed panes.
open_entries="$(printf '%s\n' "$open_panes" | jq -r '.result.panes[] | "\(.tab_id) \(.pane_id)"' 2>/dev/null | tr '\n' ' ' || true)"
target="$(awk -v closed="$closed_id" -v closed_tab="$closed_tab" -v open="$open_entries" '
  BEGIN {
    count = split(open, fields, " ")
    for (i = 1; i < count; i += 2) {
      pane_tabs[fields[i + 1]] = fields[i]
    }
  }
  { panes[NR] = $0 }
  END {
    last_closed = 0
    for (i = NR; i >= 1; i--) {
      if (panes[i] == closed) { last_closed = i; break }
    }
    if (last_closed == 0) exit
    for (i = last_closed - 1; i >= 1; i--) {
      if (panes[i] != closed && pane_tabs[panes[i]] == closed_tab) {
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
