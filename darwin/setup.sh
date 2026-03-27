#!/bin/bash

homebrew_path="/opt/homebrew"
if [ ! -d $homebrew_path ]; then
  mkdir $homebrew_path
  curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip-components 1 -C $homebrew_path
fi

brew bundle --file darwin/Brewfile

if [ -d "/Applications/Xcode.app" ]; then
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
elif ! xcode-select -p &>/dev/null; then
  xcode-select --install
fi
