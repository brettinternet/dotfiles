#!/bin/bash

# Only run interactively
# https://unix.stackexchange.com/a/257613/224048
[[ $- != *i* ]] && return

export SHELL="${BASH:-/bin/bash}"
# shellcheck source=/dev/null
. "$HOME/.profile"

BASHRC_BLACK1="\[$(tput setaf 0)\]"
BASHRC_BLACK2="\[$(tput setaf 8)\]"
BASHRC_GREEN="\[$(tput setaf 2)\]"
BASHRC_BLUE="\[$(tput setaf 4)\]"
BASHRC_RESET="\[$(tput sgr0)\]"
BASHRC_PS1_PREFIX=""
if [[ $SHOW_PROMPT_HOSTNAME = true ]]; then
  BASHRC_PS1_PREFIX="${BASHRC_BLACK1}[${BASHRC_BLACK2}\u${BASHRC_BLACK1}@${BASHRC_BLACK2}\h${BASHRC_BLACK1}] "
fi
PS1="${BASHRC_PS1_PREFIX}${BASHRC_BLUE}\W ${BASHRC_GREEN}\$${BASHRC_RESET} "

BASHRC_FUNCTIONS_DIR="$HOME/.functions"
if [ -d "$BASHRC_FUNCTIONS_DIR" ]; then
  for BASHRC_FUNCTION in "$BASHRC_FUNCTIONS_DIR"/*.sh; do
    [ -e "$BASHRC_FUNCTION" ] || continue
    # shellcheck source=/dev/null
    source "$BASHRC_FUNCTION"
  done
fi

# https://github.com/scop/bash-completion
if [[ $PS1 && -f /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck disable=SC1091
  . /usr/share/bash-completion/bash_completion
fi

unset BASHRC_BLACK1 BASHRC_BLACK2 BASHRC_GREEN BASHRC_BLUE BASHRC_RESET \
  BASHRC_PS1_PREFIX BASHRC_FUNCTIONS_DIR BASHRC_FUNCTION

export HISTCONTROL="${HISTCONTROL:+$HISTCONTROL:}erasedups:ignoreboth"

set -o noclobber

command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"

# shellcheck source=/dev/null
[ -d "/usr/share/nvm" ] && . /usr/share/nvm/init-nvm.sh
