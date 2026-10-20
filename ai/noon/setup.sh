#!/usr/bin/env bash
# Link pr-agents.yaml as each repo's private .git/noon.yaml and seed .git/noon/pr-agents.env.
# Usage: setup.sh [--force] REPO...
#   --force  move an existing non-matching .git/noon.yaml to .git/noon.yaml.bak first; refuses
#            when that backup already exists
# Never overwrites an existing pr-agents.env. Run `noon -C REPO enable` afterward; it also approves
# any shared noon.yaml jobs, so it is left to you.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd -P)
template=$here/pr-agents.yaml
env_template=$here/pr-agents.env

force=
if [[ ${1:-} == --force ]]; then
  force=1
  shift
fi
(($#)) || {
  echo "usage: $0 [--force] REPO..." >&2
  exit 2
}

status=0
for repo in "$@"; do
  if ! git_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    echo "$repo: not a git repository" >&2
    status=1
    continue
  fi
  config=$git_dir/noon.yaml
  env_file=$git_dir/noon/pr-agents.env

  if [[ -L $config && $(readlink "$config") == "$template" ]]; then
    echo "$repo: $config already linked"
  else
    if [[ -e $config || -L $config ]]; then
      if [[ -z $force ]]; then
        echo "$repo: $config exists; rerun with --force to move it to noon.yaml.bak" >&2
        status=1
        continue
      fi
      if [[ -e $config.bak || -L $config.bak ]]; then
        echo "$repo: $config.bak exists; move it aside first" >&2
        status=1
        continue
      fi
      mv "$config" "$config.bak"
      echo "$repo: moved $config to $config.bak"
    fi
    ln -s "$template" "$config"
    echo "$repo: linked $config"
  fi

  if [[ -e $env_file ]]; then
    echo "$repo: kept $env_file"
  else
    mkdir -p "${env_file%/*}"
    (umask 077 && cp "$env_template" "$env_file")
    echo "$repo: created $env_file; fill in its values"
  fi
done
exit "$status"
