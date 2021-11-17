#!/bin/bash

brew install \
  git \
  node \
  elixir \
  bpytop \
  bat \
  tmux \
  broot \
  asdf

# Tiling?
# https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)
# koekeishiya/formulae/skhd
# koekeishiya/formulae/yabai

brew install --cask \
  firefox \
  chromium \
  hyperdock \
  bitwarden \
  docker \
  visual-studio-code \
  iterm2 \
  authy \
  stats \
  spotify \
  dbeaver-community \
  zoom \
  kap \
  cyberduck \
  yippy \
  homebrew/cask-fonts/font-fira-code \
  gpg-suite \
  karabiner-elements

# Reset application attributes to allow run
xattr -cr /Applications/Chromium.app
xattr -cr /Applications/Kap.app
xattr -cr /Applications/Yippy.app

# vim plug
if [[ ! -f ~/.vim/autoload/plug.vim ]]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
