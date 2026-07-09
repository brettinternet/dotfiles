#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Collapse long paths: keep prefix (~ or /) + last 3 components, replace middle with …
IFS='/' read -r -a _segs <<< "$short_cwd"
if [ "${#_segs[@]}" -gt 5 ]; then
  n=${#_segs[@]}
  tail="${_segs[n-3]}/${_segs[n-2]}/${_segs[n-1]}"
  if [ -z "${_segs[0]}" ]; then
    short_cwd="/…/$tail"
  else
    short_cwd="${_segs[0]}/…/$tail"
  fi
fi

branch=""
dirty=""
worktree=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.hooksPath=/dev/null symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  dirty_count=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$dirty_count" -gt 0 ] && dirty="±$dirty_count"
  case "$cwd" in *"/.trees/"*) worktree="⌥" ;; esac
fi

# Server up/down probe — cached 5s to keep statusline render fast.
server=""
if [ -n "$CLAUDE_STATUSLINE_HTTP_URL" ]; then
  hash=$(printf '%s' "$CLAUDE_STATUSLINE_HTTP_URL" | shasum | cut -c1-12)
  cache="${TMPDIR:-/tmp}/claude-statusline-server.$hash"
  now=$(date +%s)
  mtime=0
  if [ -f "$cache" ]; then
    mtime=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0)
  fi
  if [ -f "$cache" ] && [ $((now - mtime)) -lt 5 ]; then
    status=$(cat "$cache")
  else
    if curl --max-time 0.3 -sf -o /dev/null "$CLAUDE_STATUSLINE_HTTP_URL" 2>/dev/null; then
      status="up"
    else
      status="down"
    fi
    printf '%s' "$status" > "$cache"
  fi
  if [ "$status" = "up" ]; then
    server=$(printf '\033[32m●\033[0m')
  else
    server=$(printf '\033[31m●\033[0m')
  fi
fi

parts=()
[ -n "$worktree" ] && parts+=("$(printf '\033[35m%s\033[0m' "$worktree")")
parts+=("$(printf '\033[34m%s\033[0m' "$short_cwd")")
if [ -n "$branch" ]; then
  if [ -n "$dirty" ]; then
    parts+=("$(printf '\033[33m(%s \033[31m%s\033[33m)\033[0m' "$branch" "$dirty")")
  else
    parts+=("$(printf '\033[33m(%s)\033[0m' "$branch")")
  fi
fi
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  parts+=("$(printf '\033[32m+%s\033[0m/\033[31m-%s\033[0m' "$added" "$removed")")
fi
[ -n "$server" ] && parts+=("$server")
parts+=("$(printf '\033[90m%s\033[0m' "$model")")
[ -n "$effort" ] && parts+=("$(printf '\033[90m%s\033[0m' "$effort")")
[ -n "$used" ] && [ "$used" != "null" ] && parts+=("$(printf '\033[90m%s%%\033[0m' "$(printf '%.0f' "$used")")")

# Pad a little from the left so the line breathes.
printf '  %s' "$(IFS='  '; echo "${parts[*]}")"
