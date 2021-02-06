#!/bin/bash

# Only run interactively
# https://unix.stackexchange.com/a/257613/224048
[[ $- != *i* ]] && return

export SHELL="/bin/bash"
source $HOME/.profile

scope() {
  local BLACK1="\[$(tput setaf 0)\]"
  local BLACK2="\[$(tput setaf 8)\]"
  local GREEN="\[$(tput setaf 2)\]"
  local BLUE="\[$(tput setaf 4)\]"
  local RESET="\[$(tput sgr0)\]"
  if [[ $SHOW_PROMPT_HOSTNAME = true ]]; then
    local PS1_PREFIX="${BLACK1}[${BLACK2}\u${BLACK1}@${BLACK2}\h${BLACK1}] "
  fi
  PS1="${PS1_PREFIX}${BLUE}\W ${GREEN}\$${RESET} "

  local FUNCTIONS_DIR="$HOME/.functions"
  if [ -d "$FUNCTIONS_DIR" ]; then
    local i; for i in $FUNCTIONS_DIR/*.sh; do source $i; done
  fi

  # https://github.com/scop/bash-completion
  if [[ $PS1 && -f /usr/share/bash-completion/bash_completion ]]; then
    . /usr/share/bash-completion/bash_completion
  fi
}

scope

source $HOME/.aliases
source $HOME/.config/broot/launcher/bash/br
source /usr/share/nvm/init-nvm.sh

# -- Fish ----------------------------------------
# https://wiki.archlinux.org/index.php/Fish#Setting_fish_as_interactive_shell_only
#if [ -z "$BASH_EXECUTION_STRING" ]; then exec fish; fi
