zinit_activate_release_command() {
  local label="$1"
  shift

  local pattern candidate
  local -aU candidates
  for pattern in "$@"; do
    candidates+=( ${~pattern}(N.) )
  done

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      REPLY="${candidate:A}"
      path=( "${REPLY:h}" $path )
      rehash
      if [[ "${REPLY:t}" != "$label" ]]; then
        eval "${label}() { ${(q)REPLY} \"\$@\"; }"
      fi
      return 0
    fi
  done

  print -u2 -r -- "zinit: $label executable missing after release update (checked: $*)"
  return 1
}

zinit_generate_file() {
  local output="$1"
  shift

  local temporary="${output}.tmp.$$"
  if "$@" >| "$temporary"; then
    command mv -f -- "$temporary" "$output"
  else
    [[ -e "$temporary" ]] && command unlink "$temporary"
    return 1
  fi
}

zinit_eval_init() {
  local label="$1"
  shift

  local init
  if init="$("$@")"; then
    eval "$init"
  else
    print -u2 -r -- "zinit: $label shell initialization failed"
    return 1
  fi
}
