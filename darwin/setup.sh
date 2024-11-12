#!/bin/bash

homebrew_path="/opt/homebrew"
if [ ! -d $homebrew_path ]; then
  mkdir $homebrew_path
  curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip-components 1 -C $homebrew_path
fi

brew bundle --file darwin/Brewfile

if ! xcode-select -p 1>/dev/null; then
  sudo xcodebuild -license accept
  xcode-select --install
fi

if ! command -v rustc; then
  # https://www.rust-lang.org/tools/install
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi
