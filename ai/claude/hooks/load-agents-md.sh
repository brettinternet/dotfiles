#!/bin/bash
set -euo pipefail

input=$(cat)
event=$(jq -r '.hook_event_name // empty' <<<"$input")
project_root=${CLAUDE_PROJECT_DIR:-}
if [[ ! -d "$project_root" ]]; then
  exit 0
fi
root_logical=$(cd "$project_root" && pwd -L)
root_physical=$(cd "$project_root" && pwd -P)
root=$root_logical

session_id=$(jq -r '.session_id // empty' <<<"$input" | tr -cd '[:alnum:]_.-')
if [[ -z "$session_id" ]]; then
  exit 0
fi
agent_id=$(jq -r '.agent_id // "main"' <<<"$input" | tr -cd '[:alnum:]_.-')
agent_id=${agent_id:-main}

umask 077
state_root=${TMPDIR:-/tmp}/claude-agents-md/$session_id
mkdir -p "$state_root"

new_generation() {
  local generation temp
  generation=$(mktemp -d "$state_root/generation.XXXXXX")
  temp=$state_root/current.$$
  printf '%s\n' "$generation" >"$temp"
  mv "$temp" "$state_root/current"
  printf '%s\n' "$generation"
}

current_generation() {
  local generation
  if [[ -f "$state_root/current" ]]; then
    IFS= read -r generation <"$state_root/current"
  fi
  if [[ -z "${generation:-}" || ! -d "$generation" ]]; then
    generation=$(new_generation)
  fi
  printf '%s\n' "$generation"
}

select_scope() {
  local path=$1 parent logical physical
  while [[ ! -d "$path" ]]; do
    parent=$(dirname "$path")
    if [[ "$parent" == "$path" ]]; then
      return 1
    fi
    path=$parent
  done
  logical=$(cd "$path" && pwd -L)
  physical=$(cd "$path" && pwd -P)
  if [[ "$logical" == "$root_logical" || "$logical" == "$root_logical/"* ]]; then
    root=$root_logical
    directory=$logical
  elif [[ "$physical" == "$root_physical" || "$physical" == "$root_physical/"* ]]; then
    root=$root_physical
    directory=$physical
  else
    return 1
  fi
}

candidate_is_allowed() {
  local candidate=$1
  [[ -f "$candidate" ]] || return 1
  if [[ "$git_repo" == true ]] && git -C "$root" check-ignore -q -- "$candidate"; then
    return 1
  fi
}

collect_applicable_files() {
  local directory=$1 generation=$2 candidate relative marker part git_repo=false
  local -a parts candidates
  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_repo=true
  fi
  candidates=()
  candidate=$root
  if candidate_is_allowed "$candidate/AGENTS.md"; then
    candidates+=("$candidate/AGENTS.md")
  fi

  relative=${directory#"$root"}
  relative=${relative#/}
  if [[ -n "$relative" ]]; then
    IFS='/' read -r -a parts <<<"$relative"
    for part in "${parts[@]}"; do
      candidate=$candidate/$part
      if candidate_is_allowed "$candidate/AGENTS.md"; then
        candidates+=("$candidate/AGENTS.md")
      fi
    done
  fi

  files=()
  for candidate in "${candidates[@]}"; do
    relative=${candidate#"$root"/}
    marker=$generation/loaded/$agent_id/$relative
    mkdir -p "$(dirname "$marker")"
    if mkdir "$marker" 2>/dev/null; then
      files+=("$candidate")
    fi
  done
}

render_context() {
  local file relative
  printf '%s\n' '<agents-md-context>'
  printf '%s\n' 'These AGENTS.md instructions now apply to the accessed path. Files are scoped to their containing directory and descendants; deeper files take precedence.'
  for file in "${files[@]}"; do
    relative=${file#"$root"/}
    printf '\n--- %s ---\n' "$relative"
    cat "$file"
  done
  printf '\n%s\n' '</agents-md-context>'
}

cwd=$(jq -r '.cwd // empty' <<<"$input")
case "$event" in
  SessionStart)
    generation=$(new_generation)
    select_scope "${cwd:-$project_root}" || exit 0
    ;;
  PreToolUse)
    generation=$(current_generation)
    tool_name=$(jq -r '.tool_name // empty' <<<"$input")
    case "$tool_name" in
      Read|Edit|Write)
        target=$(jq -r '.tool_input.file_path // empty' <<<"$input")
        [[ -n "$target" ]] || exit 0
        select_scope "$(dirname "$target")" || exit 0
        ;;
      NotebookEdit)
        target=$(jq -r '.tool_input.notebook_path // empty' <<<"$input")
        [[ -n "$target" ]] || exit 0
        select_scope "$(dirname "$target")" || exit 0
        ;;
      Glob|Grep)
        target=$(jq -r '.tool_input.path // empty' <<<"$input")
        target=${target:-${cwd:-$project_root}}
        if [[ "$target" != /* ]]; then
          target=${cwd:-$root}/$target
        fi
        if [[ -f "$target" ]]; then
          target=$(dirname "$target")
        fi
        select_scope "$target" || exit 0
        ;;
      LSP)
        target=$(jq -r '.tool_input.filePath // .tool_input.file_path // .tool_input.file // empty' <<<"$input")
        [[ -n "$target" ]] || exit 0
        select_scope "$(dirname "$target")" || exit 0
        ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

collect_applicable_files "$directory" "$generation"
if (( ${#files[@]} == 0 )); then
  exit 0
fi

context=$(render_context)
if [[ "$event" == "SessionStart" ]]; then
  printf '%s\n' "$context"
else
  jq -nc --arg context "$context" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $context}}'
fi
