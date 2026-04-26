#!/bin/sh

# shellcheck disable=SC3045
ulimit -n 4096 2>/dev/null || true

# To allow for some customization across workspaces
profile_workspace_only_env="$HOME/.envrc"
if [ -f "$profile_workspace_only_env" ]; then
  # shellcheck source=/dev/null
  . "$profile_workspace_only_env"
fi

# Personal binaries
export PATH="$HOME/.bin:/opt/bin:$PATH"

# https://wiki.archlinux.org/index.php/Sudo#Using_visudo
export VISUAL=vim
export EDITOR="$VISUAL"
export SYSTEMD_EDITOR="$EDITOR"

# https://wiki.archlinux.org/index.php/Environment_variables#Default_programs
if [ -z "$DISPLAY" ]; then
  export BROWSER=w3m
fi

# If we haven't set the shell yet, use bash
if [ -z "$SHELL" ]; then
  export SHELL=/bin/bash
fi

profile_rust_env_file="$HOME/.cargo/env"
if [ -f "$profile_rust_env_file" ]; then
  # shellcheck source=/dev/null
  . "$profile_rust_env_file"
fi

if [ -f /usr/bin/virtualenvwrapper_lazy.sh ]; then
  # https://wiki.archlinux.org/index.php/Python/Virtual_environment#virtualenvwrapper
  export WORKON_HOME="$HOME/.virtualenvs"
  # shellcheck source=/dev/null
  . /usr/bin/virtualenvwrapper_lazy.sh
elif [ -f /opt/homebrew/bin/virtualenvwrapper_lazy.sh ]; then
  export WORKON_HOME="$HOME/.virtualenvs"
  export VIRTUALENVWRAPPER_PYTHON=/opt/homebrew/bin/python3
  # shellcheck source=/dev/null
  . /opt/homebrew/bin/virtualenvwrapper_lazy.sh
fi

# https://guides.rubygems.org/faqs/#user-install
if command -v ruby >/dev/null 2>&1 && command -v gem >/dev/null 2>&1; then
  profile_gem_user_bin="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin"
  export PATH="$profile_gem_user_bin:$PATH"
fi

# global NPM packages: https://docs.npmjs.com/resolving-eacces-permissions-errors-when-installing-packages-globally
# Set custom gopath because I prefer it to be a hidden folder
export GOPATH="$HOME/.go"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$GOPATH/bin:$HOME/.cargo/bin:$PATH:$HOME/.config/emacs/bin"

# Don't timeout in terminal multiplexer
if [ "${TERM#screen}" = "$TERM" ] && [ -z "$TMUX" ] && [ -z "$DISPLAY" ] && [ "$(uname)" != "Darwin" ]; then
  # Automatically logout inactive consoles after 10 min: https://wiki.archlinux.org/index.php/Security#Automatic_logout
  # Applies to SSH sessions as well, but unintended for terminal emulation where $DISPLAY is set
  profile_ten_minutes="$((60 * 10))"
  export TMOUT="$profile_ten_minutes"
  case "$(/usr/bin/tty)" in
    /dev/tty[0-9]*) export TMOUT="$profile_ten_minutes" ;;
  esac
else
  unset TMOUT
fi

# https://unix.stackexchange.com/a/94508
profile_dircolors="$HOME/.dircolors"
if [ -f "$profile_dircolors" ] && command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors "$profile_dircolors")"
fi

# Common utility replacements via aliases
if [ -x "$(command -v lsd)" ]; then
  alias ls='lsd'
elif [ "$(uname)" = "Darwin" ]; then
  alias ls='ls -G'
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

profile_bun_bin="$HOME/.bun/bin"
if [ -d "$profile_bun_bin" ]; then
  export PATH="$profile_bun_bin:$PATH"
fi

unset profile_workspace_only_env profile_rust_env_file profile_gem_user_bin \
  profile_ten_minutes profile_dircolors profile_bun_bin
