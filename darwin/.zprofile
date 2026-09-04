() {
  local in_admin_group effective_uid
  in_admin_group=$(id -nG | grep -qw "admin" && echo true || echo false)
  effective_uid=$(id -u)

  # Load brew path
  if [[ "$effective_uid" -eq 0 ]] || [[ "$in_admin_group" == true ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  if [[ -d "/Applications/Ghostty.app" ]]; then
    export PATH="$PATH:/Applications/Ghostty.app/Contents/MacOS"
  fi
}
