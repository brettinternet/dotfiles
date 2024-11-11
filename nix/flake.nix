# Nix annoyances:
# - git add first? 🤔 https://github.com/NixOS/nix/issues/6642
{
  description = "My nix-darwin system flake";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # https://github.com/LnL7/nix-darwin
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # https://github.com/zhaofengli/nix-homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    # homebrew-core = {
    #   url = "github:homebrew/homebrew-core";
    #   flake = false;
    # };
    # homebrew-cask = {
    #   url = "github:homebrew/homebrew-cask";
    #   flake = false;
    # };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, ... }: {
    # Build flake: darwin-rebuild build --flake .#bort
    darwinConfigurations = {
      "kipp" = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/kipp
          # nix-homebrew.darwinModules.nix-homebrew
          # {
          #   nix-homebrew = {
          #     enable = true;
          #     enableRosetta = true;
          #     user = "brett";
          #     taps = {
          #       "homebrew/homebrew-core" = homebrew-core;
          #       "homebrew/homebrew-cask" = homebrew-cask;
          #     };
          #     mutableTaps = false;
          #     autoMigrate = true; # Disable if new setup
          #   };
          # }
        ];
      };
    };
    darwinPackages = self.darwinConfigurations."kipp".pkgs;
  };
}
