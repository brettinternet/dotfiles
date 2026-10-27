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

readonly XCODE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
readonly CLT_DEVELOPER_DIR="/Library/Developer/CommandLineTools"

# Xcode's linker can lag behind a newer Command Line Tools SDK on a newer macOS.
links_c() {
  echo 'int main(void){return 0;}' \
    | DEVELOPER_DIR="$1" xcrun clang -x c - -o /dev/null >/dev/null 2>&1
}

if [ -d "${XCODE_DEVELOPER_DIR}" ] && links_c "${XCODE_DEVELOPER_DIR}"; then
  sudo xcode-select -s "${XCODE_DEVELOPER_DIR}"
  sudo xcodebuild -license accept
elif [ -d "${CLT_DEVELOPER_DIR}" ]; then
  sudo xcode-select -s "${CLT_DEVELOPER_DIR}"
elif ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
fi
