# Load brew path
eval "$(/opt/homebrew/bin/brew shellenv)"

# https://github.com/asdf-vm/asdf
if [ -d /opt/homebrew/opt/asdf/ ]; then
  source /opt/homebrew/opt/asdf/libexec/asdf.sh
fi
