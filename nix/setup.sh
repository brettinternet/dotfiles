#!/bin/bash

# Note: flake is not accessible through symlink - https://github.com/NixOS/nix/issues/8013

# Install Nix
# https://nixos.org/download/
if [ -z "$(command -v nix)" ]; then
  sh <(curl -L https://nixos.org/nix/install)
fi

function run_nix() {
  local nix_cmd=(nix --extra-experimental-features nix-command --extra-experimental-features flakes)
  local cmd=("${nix_cmd[@]}" "$@")
  "${cmd[@]}"
}

nix_darwin_config_dir=$HOME/.dotfiles/nix
nix_config_name="bort"

# Install Nix-darwin
# https://github.com/LnL7/nix-darwin#flakes
if [ ! -f $nix_darwin_config_dir/flake.nix ]; then
  mkdir -p $nix_darwin_config_dir
  cd $nix_darwin_config_dir
  run_nix flake init -t nix-darwin
  sed -i '' "s/simple/$nix_config_name/" flake.nix
fi

run_nix run nix-darwin -- switch --flake $nix_darwin_config_dir#$nix_config_name
source ~/.zshrc # reload shell in case darwin-rebuild isn't available
darwin-rebuild switch --flake $nix_darwin_config_dir

xattr -cr /Applications/UnnaturalScrollWheels.app

if ! xcode-select -p 1>/dev/null; then
  xcode-select --install
fi
