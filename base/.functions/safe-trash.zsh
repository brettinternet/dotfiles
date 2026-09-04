# Refuse accidental removal of critical roots or the active working tree.
trash() {
  emulate -L zsh

  local argument resolved_target current_directory protected_path
  local parsing_options=true
  local -a protected_paths=(
    /
    "${HOME:A}"
    "${HOME:A}/.dotfiles"
    "${HOME:A}/.config"
    "${HOME:A}/.ssh"
    "${HOME:A}/.gnupg"
    "${HOME:A}/.local"
    "${HOME:A}/.pi"
    "${HOME:A}/.omp"
    "${HOME:A}/.claude"
    "${HOME:A}/.codex"
    "${HOME:A}/.Trash"
  )

  current_directory="${PWD:A}"
  for argument in "$@"; do
    if $parsing_options && [[ "$argument" == -- ]]; then
      parsing_options=false
      continue
    fi
    if $parsing_options && [[ "$argument" == -* ]]; then
      continue
    fi

    resolved_target="${argument:A}"
    for protected_path in "${protected_paths[@]}"; do
      if [[ "$resolved_target" == "$protected_path" ]]; then
        print -u2 -- "Refusing to trash protected path: $resolved_target"
        print -u2 -- "Use the external trash command explicitly after verifying the path."
        return 2
      fi
    done

    if [[ "$current_directory" == "$resolved_target" || "$current_directory" == "$resolved_target"/* ]]; then
      print -u2 -- "Refusing to trash the current directory or its ancestor: $resolved_target"
      return 2
    fi
  done

  command trash "$@"
}
