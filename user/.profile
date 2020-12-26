#!/bin/sh

# To allow for some customization across workspaces
WORKSPACE_ONLY_ENV=$HOME/.env
if [ -f $WORKSPACE_ONLY_ENV ]; then
    . $WORKSPACE_ONLY_ENV
fi

# https://wiki.archlinux.org/index.php/Sudo#Using_visudo
export VISUAL=vim
export EDITOR="$VISUAL"

# https://wiki.archlinux.org/index.php/Environment_variables#Default_programs
if [ ! -n "$DISPLAY" ]; then
    export BROWSER=w3m
fi

# If we haven't set the shell yet, use bash
if [ -z "$SHELL" ]; then
    export SHELL=/bin/bash
fi

# Personal desktop environment scripts,
# more useful here than .profile because .xprofile is loaded before i3 in .xinitrc
PERSONAL_BIN=${MY_BIN:-$MY_DOTFILES/bin}
if [ -d "$PERSONAL_BIN" ]; then
    export PATH=$PATH:$PERSONAL_BIN
fi

# https://guides.rubygems.org/faqs/#user-install
if which ruby >/dev/null && which gem >/dev/null; then
    PATH="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin:$PATH"
fi

# global NPM packages: https://docs.npmjs.com/resolving-eacces-permissions-errors-when-installing-packages-globally
# Haskell stack et al
# Also, set custom gopath because I prefer it to be a hidden folder
export GOPATH=~/.go
CUSTOM_PATH=~/.npm-global/bin:~/.local/bin:$GOPATH/bin:~/.cargo/bin
export PATH=$CUSTOM_PATH:$PATH