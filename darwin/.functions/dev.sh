#!/bin/bash

function wt-list() {
  git worktree list | tail -n +2 | awk '{print $3}' | tr -d '[]'
}

function wt-new() {
  local branch=$1
  git worktree add -b "$branch" ".trees/$branch" main
  open -a "$TERM_PROGRAM" "$(pwd)/.trees/$branch"
}

function wt-delete() {
  local branch=${1:-$(git branch --show-current)}
  local root
  root=$(git worktree list | head -1 | awk '{print $1}')

  git -C "$root" worktree remove ".trees/$branch" --force
  git -C "$root" branch -d "$branch"
}

function wt-clean() {
  local branch=""
  local force=0

  # Parse args
  for arg in "$@"; do
    case "$arg" in
      -f|--force) force=1 ;;
      *) branch="$arg" ;;
    esac
  done

  branch=${branch:-$(git branch --show-current)}
  local root
  root=$(git worktree list | head -1 | awk '{print $1}')
  local tree="$root/.trees/$branch"

  if [[ $force -eq 0 ]]; then
    # Uncommitted changes
    if ! git -C "$tree" diff --quiet || ! git -C "$tree" diff --cached --quiet; then
      echo "wt-clean: '$branch' has uncommitted changes. Use -f to force." >&2
      return 1
    fi

    # Unpushed commits
    local upstream
    upstream=$(git -C "$tree" rev-parse --abbrev-ref "@{upstream}" 2>/dev/null)
    if [[ -z "$upstream" ]]; then
      echo "wt-clean: '$branch' has no remote tracking branch. Use -f to force." >&2
      return 1
    fi
    if [[ -n $(git -C "$tree" log "$upstream..HEAD" 2>/dev/null) ]]; then
      echo "wt-clean: '$branch' has unpushed commits. Use -f to force." >&2
      return 1
    fi
  fi

  git -C "$root" worktree remove "$tree" --force
  git -C "$root" branch -d "$branch" 2>/dev/null || git -C "$root" branch -D "$branch"
  cd "$root" || return
}

function wt-switch() {
  local branch=$1
  local root=$(git worktree list | head -1 | awk '{print $1}')
  local default=$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
  default=${default:-main}

  if [[ -z "$branch" ]]; then
    if command -v fzf &>/dev/null; then
      branch=$(git worktree list | tail -n +2 | awk '{print $3}' | tr -d '[]' | fzf --prompt="worktree> ")
    else
      echo "Usage: wt-switch <branch>" >&2
      git worktree list
      return 1
    fi
  fi

  if [[ "$branch" == "$default" ]]; then
    open -a "$TERM_PROGRAM" "$root"
    return 0
  fi

  local tree="$root/.trees/$branch"

  if [[ ! -d "$tree" ]]; then
    echo "wt-switch: no worktree for '$branch'. Use wt-new to create one." >&2
    return 1
  fi

  open -a "$TERM_PROGRAM" "$tree"
}
