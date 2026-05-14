#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly BREWFILE="${SCRIPT_DIR}/Brewfile"
readonly HOMEBREW_PREFIX="/opt/homebrew"

if ! command -v brew >/dev/null 2>&1; then
  if [ ! -d "${HOMEBREW_PREFIX}" ]; then
    sudo mkdir -p "${HOMEBREW_PREFIX}"
    sudo chown "$(id -un):$(id -gn)" "${HOMEBREW_PREFIX}"
    curl -fsSL https://github.com/Homebrew/brew/tarball/master \
      | tar xz --strip-components 1 -C "${HOMEBREW_PREFIX}"
  fi

  eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"
fi

brew bundle --file "${BREWFILE}"

if [ -d "/Applications/Xcode.app" ]; then
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
elif ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
fi
