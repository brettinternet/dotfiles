# Load brew path
eval "$(/opt/homebrew/bin/brew shellenv)"

# https://github.com/asdf-vm/asdf
if [ -d /opt/homebrew/opt/asdf/ ]; then
  source /opt/homebrew/opt/asdf/libexec/asdf.sh
fi

export NVM_DIR="$HOME/.nvm"

[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
