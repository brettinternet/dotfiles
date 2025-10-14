#!/bin/sh

scope() {
  ulimit -n 4096

  # To allow for some customization across workspaces
  local WORKSPACE_ONLY_ENV=$HOME/.envrc
  if [ -f $WORKSPACE_ONLY_ENV ]; then
    source $WORKSPACE_ONLY_ENV
  fi

  # Personal binaries
  export PATH=~/.bin:/opt/bin:$PATH

  # https://wiki.archlinux.org/index.php/Sudo#Using_visudo
  export VISUAL=vim
  export EDITOR="$VISUAL"
  export SYSTEMD_EDITOR="$EDITOR"

  # https://wiki.archlinux.org/index.php/Environment_variables#Default_programs
  if [ ! -n "$DISPLAY" ]; then
    export BROWSER=w3m
  fi

  # If we haven't set the shell yet, use bash
  if [ -z "$SHELL" ]; then
    export SHELL=/bin/bash
  fi

  RUST_ENV_FILE="$HOME/.cargo/env"
  if [ -f "$RUST_ENV_FILE" ]; then
    source "$RUST_ENV_FILE"
  fi

  if [ -f /usr/bin/virtualenvwrapper_lazy.sh ]; then
    # https://wiki.archlinux.org/index.php/Python/Virtual_environment#virtualenvwrapper
    export WORKON_HOME=~/.virtualenvs
    source /usr/bin/virtualenvwrapper_lazy.sh
  elif [ -f /opt/homebrew/bin/virtualenvwrapper_lazy.sh ]; then
    export WORKON_HOME=~/.virtualenvs
    export VIRTUALENVWRAPPER_PYTHON=/opt/homebrew/bin/python3
    source /opt/homebrew/bin/virtualenvwrapper_lazy.sh
  fi

  # https://guides.rubygems.org/faqs/#user-install
  if which ruby >/dev/null && which gem >/dev/null; then
    export PATH="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin:$PATH"
  fi

  # global NPM packages: https://docs.npmjs.com/resolving-eacces-permissions-errors-when-installing-packages-globally
  # Set custom gopath because I prefer it to be a hidden folder
  export GOPATH=~/.go
  export PATH=~/.npm-global/bin:~/.local/bin:$GOPATH/bin:~/.cargo/bin:$PATH:~/.config/emacs/bin

  # Don't timeout in terminal multiplexer
  if [[ $TERM != screen* ]] && ! [ -n "$TMUX" ] && [ -z "$DISPLAY" ] && [ "$(uname)" != "Darwin" ]; then
    # Automatically logout inactive consoles after 10 min: https://wiki.archlinux.org/index.php/Security#Automatic_logout
    # Applies to SSH sessions as well, but unintended for terminal emulation where $DISPLAY is set
    local TEN_MINUTES="$(( 60*10 ))"
    export TMOUT=$TEN_MINUTES
    case $( /usr/bin/tty ) in
      /dev/tty[0-9]*) export TMOUT=$TEN_MINUTES;;
    esac
  else
    unset TMOUT
  fi

  # https://unix.stackexchange.com/a/94508
  local DIRCOLORS=$HOME/.dircolors
  if [[ -f $DIRCOLORS ]]; then
    eval "$(dircolors $DIRCOLORS)"
  fi
  # Common utility replacements via aliases
  if [ -x "$(command -v lsd)" ]; then
    alias ls='lsd'
  else
    alias ls='ls --color=auto'
  fi
  if [ -x "$(command -v bat)" ]; then
    alias cat='bat --theme=ansi'
  fi
  if [ -x "$(command -v kubecolor)" ]; then
    alias kubectl='kubecolor'
  fi
  alias k='kubectl'
}

scope
