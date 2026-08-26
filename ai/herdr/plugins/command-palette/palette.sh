#!/bin/sh
set -eu

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
herdr_bin=${HERDR_BIN_PATH:-herdr}

selected=$(
  "$herdr_bin" plugin action list |
    jq -r '.result.actions[] | select(.plugin_id != "brett.command-palette" or .action_id != "open") | [.title, .plugin_id, .action_id] | @tsv' |
    fzf --delimiter='\t' --with-nth=1 --prompt='Herdr command> '
) || exit 0

plugin_id=$(printf '%s\n' "$selected" | cut -f2)
action_id=$(printf '%s\n' "$selected" | cut -f3)
exec "$herdr_bin" plugin action invoke "$action_id" --plugin "$plugin_id"
