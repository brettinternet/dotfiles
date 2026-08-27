#!/bin/sh
set -eu

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
history_file="$state_dir/previous-pane-focus.history"
[ -f "$history_file" ] || exit 0

closed_id="${HERDR_PANE_ID:-}"
[ -n "$closed_id" ] || exit 0

# Walk back from the closed pane's last recorded focus to whatever was
# focused immediately before it - that's the pane herdr's default
# next-pane pick should be overridden with.
target="$(awk -v closed="$closed_id" '
  { lines[NR] = $0 }
  END {
    last_closed = 0
    for (i = NR; i >= 1; i--) {
      if (lines[i] == closed) { last_closed = i; break }
    }
    if (last_closed == 0) exit
    for (i = last_closed - 1; i >= 1; i--) {
      if (lines[i] != closed) { print lines[i]; exit }
    }
  }
' "$history_file")"

[ -n "$target" ] || exit 0

# Only agent panes can be focused by pane id today; skip quietly for plain
# shell panes (herdr's default focus stands - no regression either way).
open_ids="$(herdr pane list 2>/dev/null | jq -r '.result.panes[].pane_id' 2>/dev/null | tr '\n' ' ' || true)"
case " $open_ids " in
  *" $target "*) herdr agent focus "$target" >/dev/null 2>&1 || true ;;
esac
