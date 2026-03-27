#!/bin/bash

# Applications
alias c="code ."
alias z="zed ."

# Navigation
DEV_DIR="$HOME/dev"
PERSONAL_DIR="${MY_PROJECTS:-$DEV_DIR/me}"
alias dev='cd $DEV_DIR'
alias me='cd $PERSONAL_DIR'
alias sandbox='cd $DEV_DIR/sandbox'
alias work='cd $DEV_DIR/work'

# shellcheck disable=SC2034
NOTES_DIR="${MY_NOTES:-$PERSONAL_DIR/notes}"
# associated with a private folder with notes, delcared as `$MY_NOTES` in ~/.envrc
alias notes='cd $NOTES_DIR'
alias todo='$EDITOR $NOTES_DIR/daily/todo'
alias note='$EDITOR $NOTES_DIR/daily/notes'

alias claude='claude --ide'

function flush_dns() {
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
}

function wt-new() {
  local branch=$1
  git worktree add -b "$branch" ".trees/$branch" main
  open -a $TERM_PROGRAM "$(pwd)/.trees/$branch"
}

function wt-delete() {
  local branch=${1:-$(git branch --show-current)}
  local root=$(git worktree list | head -1 | awk '{print $1}')

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
  local root=$(git worktree list | head -1 | awk '{print $1}')
  local tree="$root/.trees/$branch"

  if [[ $force -eq 0 ]]; then
    # Uncommitted changes
    if ! git -C "$tree" diff --quiet || ! git -C "$tree" diff --cached --quiet; then
      echo "wt-clean: '$branch' has uncommitted changes. Use -f to force." >&2
      return 1
    fi

    # Unpushed commits
    local upstream=$(git -C "$tree" rev-parse --abbrev-ref "@{upstream}" 2>/dev/null)
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
  cd "$root"
}
