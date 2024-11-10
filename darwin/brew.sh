#!/bin/bash

brew bundle --file darwin/Brewfile

# Reset application attributes to allow run
xattr -cr /Applications/Chromium.app
xattr -cr /Applications/Yippy.app
xattr -cr /Applications/UnnaturalScrollWheels.app

xcode-select --install

# vim plug
if [[ ! -f ~/.vim/autoload/plug.vim ]]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

if ! command -v rustc; then
  # https://www.rust-lang.org/tools/install
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi
