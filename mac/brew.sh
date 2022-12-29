#!/bin/bash

brew bundle --file mac/Brewfile

# Reset application attributes to allow run
xattr -cr /Applications/Chromium.app
xattr -cr /Applications/Yippy.app
xattr -cr /Applications/UnnaturalScrollWheels.app

# xcode-select --install

# vim plug
if [[ ! -f ~/.vim/autoload/plug.vim ]]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
