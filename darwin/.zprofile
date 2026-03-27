# Load brew path
eval "$(/opt/homebrew/bin/brew shellenv)"

if [ -d /Applications/Ghostty.app ]; then
  export PATH="$PATH:/Applications/Ghostty.app/Contents/MacOS"
fi
