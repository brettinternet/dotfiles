#!/bin/bash

# Source: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git

# Source: https://github.com/ohmyzsh/ohmyzsh/blob/4e45e12dc355e3ba34e7e40ce4936fb222f0155c/plugins/git/git.plugin.zsh#L21-L26
# These features allow to pause a branch development and switch to another one ("Work in Progress", or wip). When you want to go back to work, just unwip it.
# Warn if the current branch is a WIP
function work_in_progress {
  # shellcheck disable=SC2091
  if "$(git log -n 1 2>/dev/null | grep -q -c "\-\-wip\-\-")"; then
    echo "WIP!!"
  fi
}

# Source: https://github.com/ohmyzsh/ohmyzsh/blob/4e45e12dc355e3ba34e7e40ce4936fb222f0155c/plugins/git/git.plugin.zsh#L257
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign -m "--wip-- [skipci]"'
alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'

function git_pickaxe { # 1 - search string value
  if [ $# -eq 0 ]; then
      echo "No arguments provided"
      exit 1
  fi
  local STRING="$1"
  # Search string, show diff and commit message, chronological order
  git log -S "$STRING" --patch --reverse
}

# Source: https://github.com/ohmyzsh/ohmyzsh/blob/1546e1226a7b739776bda43f264b221739ba0397/lib/git.zsh#L68-L81
# Outputs the name of the current branch
# Usage example: git pull origin $(git_current_branch)
# Using '--quiet' with 'symbolic-ref' will not cause a fatal error (128) if
# it's not a symbolic ref, but in a Git repo.
function git_current_branch {
  local ref
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo "${ref#refs/heads/}"
}

# https://stackoverflow.com/a/4822516
# Exclude certain files not gitignored - https://stackoverflow.com/a/53083343
function gloc { # 1 - additional filter patterns
  git ls-files -- ':!:*lock.json' "$1" | xargs cat | wc -l
}

alias guc='git pull origin "$(git_current_branch)"'
alias gpc='git push origin "$(git_current_branch)"'
alias gpcf='git push --force-with-lease origin "$(git_current_branch)"'

alias gbsuc='git branch --set-upstream-to=origin/$(git_current_branch)'
alias gpsuc='git push --set-upstream origin $(git_current_branch)'

alias grbo='git rebase'
function grbos {
  local branch="${1:-main}"
  git rebase --exec "git commit --amend --no-edit -n -S" -i origin/"$branch"
}

function g_sign { # 1 - email, 2 - GPG key ID
  local email="$1"
  local key_id="$2"
  if [[ -z "$email" ]]; then
    echo "Missing email as the first argument"
    return 1
  fi
  if [[ -z "$key_id" ]]; then
    echo "Missing key ID as the second argument"
    return 1
  fi
  if [[ ! $(gpg -k "$key_id") ]]; then
    echo "Unable to find GPG key by that ID"
    return 1
  fi
  if [[ ! $(gpg -k "$email") ]]; then
    echo "That email does not match a local GPG key"
    return 1
  fi
  git config user.signingkey "$key_id"
  git config commit.gpgsign true
  git config tag.gpgsign true
  git config user.email "$email"
}

alias g='git'
alias gb='git branch'
alias gs='git status'
alias gss='git status -s'
alias gst='git stash'
alias gsp='git stash pop'
alias gsa='git stash apply'
alias gsh='git show'
alias gi='vim .gitignore'
alias ga='git add'
alias gaa='git add -A'
alias gcm='git commit -m'
alias gscm='git commit -S -m'
alias grv='git remote -v'
alias grr='git remote rm'
alias gra='git remote add'
alias glog='git l'
alias gf='git fetch'
alias gd='git diff'
alias gp='git push'
alias gu='git pull'
alias guom='git pull origin main'
alias gpom='git push origin main'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'

alias gwtl='git worktree list'
alias gwta='git worktree add'
alias gwtr='git worktree remove'
alias gwtp='git worktree prune'
alias gwt='gwta'

function gwta {
  local worktree_name="$1"
  local branch_name="${2:-$1}"

  if [[ -z "$worktree_name" ]]; then
    echo "Usage: gwt <worktree_name> [branch_name]"
    return 1
  fi

  local current_dir=$(basename "$(git rev-parse --show-toplevel)")
  local new_worktree_name="${current_dir}-${worktree_name}"
  local worktree_path="$(git rev-parse --show-toplevel)/../${new_worktree_name}"

  if [[ -n "$branch_name" ]]; then
    git worktree add -b "$branch_name" "$worktree_path"
  else
    git worktree add "$worktree_path"
  fi
}
