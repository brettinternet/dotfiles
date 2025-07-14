#!/bin/bash

# Only run interactively
# https://unix.stackexchange.com/a/257613/224048
[[ $- != *i* ]] && return

export SHELL="/usr/bin/bash"
# shellcheck source=/dev/null
. "$HOME/.profile"

scope() {
  local BLACK1 BLACK2 GREEN BLUE RESET
  BLACK1="\[$(tput setaf 0)\]"
  BLACK2="\[$(tput setaf 8)\]"
  GREEN="\[$(tput setaf 2)\]"
  BLUE="\[$(tput setaf 4)\]"
  RESET="\[$(tput sgr0)\]"
  if [[ $SHOW_PROMPT_HOSTNAME = true ]]; then
    local PS1_PREFIX="${BLACK1}[${BLACK2}\u${BLACK1}@${BLACK2}\h${BLACK1}] "
  fi
  PS1="${PS1_PREFIX}${BLUE}\W ${GREEN}\$${RESET} "

  local FUNCTIONS_DIR="$HOME/.functions"
  # shellcheck source=/dev/null
  if [ -d "$FUNCTIONS_DIR" ]; then
    local i; for i in "$FUNCTIONS_DIR"/*.sh; do source "$i"; done
  fi

  # https://github.com/scop/bash-completion
  if [[ $PS1 && -f /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck disable=SC1091
    . /usr/share/bash-completion/bash_completion
  fi
}

scope

export HISTCONTROL="$HISTCONTROL erasedups:ignoreboth"

set -o noclobber

eval "$(mise activate bash)"

# shellcheck source=/dev/null
[ -d "$HOME/.config/broot" ] && . "$HOME/.config/broot/launcher/bash/br"
# shellcheck source=/dev/null
[ -d "/usr/share/nvm" ] && . /usr/share/nvm/init-nvm.sh

