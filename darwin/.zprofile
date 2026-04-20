IN_ADMIN_GROUP=$(id -nG | grep -qw "admin" && echo true || echo false)
EFFECTIVE_UID=$(id -u)

# Load brew path
if [[ "$EFFECTIVE_UID" -eq 0 ]] || [[ "$IN_ADMIN_GROUP" == true ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ -d /Applications/Ghostty.app ]; then
  export PATH="$PATH:/Applications/Ghostty.app/Contents/MacOS"
fi
