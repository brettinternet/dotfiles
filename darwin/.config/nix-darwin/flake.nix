{
  description = "brett's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      # Search packages: nix-env -qaP | grep wget
      environment.systemPackages =
        [
          pkgs.neovim
          pkgs.tmux
        ];
      services.nix-daemon.enable = true;
      nix.settings.experimental-features = "nix-command flakes";
      programs.zsh.enable = true;
      system.configurationRevision = self.rev or self.dirtyRev or null;
      # Read changelog before upgrading: darwin-rebuild changelog
      system.stateVersion = 5;
      nixpkgs.hostPlatform = "aarch64-darwin";
      time.timeZone = "America/Denver";
    };
  in
  {
    # Build flake: darwin-rebuild build --flake .#macbook
    darwinConfigurations."macbook" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
    darwinPackages = self.darwinConfigurations."macbook".pkgs;
  };
}
