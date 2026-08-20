#!/bin/bash
set -euo pipefail

root=${CLAUDE_PROJECT_DIR:-}
if [[ ! -d "$root" ]]; then
  exit 0
fi

files=()
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r -d '' path; do
    files+=("$root/$path")
  done < <(git -C "$root" ls-files -z --cached --others --exclude-standard -- 'AGENTS.md' ':(glob)**/AGENTS.md')
else
  while IFS= read -r -d '' path; do
    files+=("$path")
  done < <(find "$root" -type d \( -name .git -o -name node_modules \) -prune -o -type f -name AGENTS.md -print0)
fi

if (( ${#files[@]} == 0 )); then
  exit 0
fi

printf '%s\n' '<agents-md-context>'
printf '%s\n' 'AGENTS.md files are scoped to their containing directory and descendants. More deeply nested files take precedence.'
for file in "${files[@]}"; do
  relative=${file#"$root"/}
  printf '\n--- %s ---\n' "$relative"
  cat "$file"
done
printf '\n%s\n' '</agents-md-context>'
