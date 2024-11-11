# Nix annoyances:
# - git add first? 🤔 https://github.com/NixOS/nix/issues/6642

{
  description = "brett's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # https://github.com/LnL7/nix-darwin
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # https://github.com/zhaofengli/nix-homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, homebrew-core, homebrew-cask }:
  let
    configuration = { pkgs, ... }: {
      # Search packages: nix-env -qaP | grep wget
      environment.systemPackages = [
        pkgs.asdf
        pkgs.atuin
        pkgs.bat
        pkgs.broot
        pkgs.btop
        pkgs.coreutils
        pkgs.elixir
        pkgs.fd
        pkgs.git
        pkgs.go-task
        pkgs.lsd
        pkgs.mas
        pkgs.neovim
        pkgs.qrencode
        pkgs.rustc
        pkgs.terminal-notifier
        pkgs.tmux
        pkgs.trash-cli
        pkgs.wget
      ];
      homebrew = {
        enable = true;
        taps = [
          "finestructure/Hummingbird"
        ];
        brews = [
          "finestructure/hummingbird/hummingbird"
          "nvm"
          "virtualenvwrapper"
          "wireguard-tools"
        ];
        casks = [
          "balenaetcher"
          "datagrip"
          "docker"
          "elgato-control-center"
          "elgato-stream-deck"
          "font-fira-code"
          "font-hack-nerd-font"
          "google-chrome"
          "gpg-suite"
          "hammerspoon"
          "home-assistant"
          "iterm2"
          "karabiner-elements"
          "kopiaui"
          "maccy"
          "obs"
          "plex"
          "postico"
          "raspberry-pi-imager"
          "slack"
          "stats"
          "spotify"
          "telegram"
          "unnaturalscrollwheels"
          "vnc-viewer"
          "visual-studio-code"
          "vlc"
          "zoom"
        ];
        masApps = {
          "AdGuard for Safari" = 1440147259;
          "Bitwarden" = 1352778147; # appstore for safari support
          "WiFiman" = 1385561119;
          "Windows App" = 1295203466; # Microsoft Remote Desktop
          "Xcode" = 497799835;
        };
        # onActivation.cleanup = "zap";
      };

      system.defaults = {
        dock.autohide = true;
        dock.persistent-apps = [];
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled = false;
      };

      services.nix-daemon.enable = true;
      nix.settings.experimental-features = "nix-command flakes";
      programs.zsh.enable = true;
      system.configurationRevision = self.rev or self.dirtyRev or null;
      # Read changelog before upgrading: darwin-rebuild changelog
      system.stateVersion = 5;
      nixpkgs.hostPlatform = "aarch64-darwin";
      time.timeZone = "America/Denver";

      # darwinConfigurations = nix-darwin.lib.darwinSystem {
      #   # modules = [ ./darwin ];
      #   nix.extraOptions = ''
      #     extra-platforms = aarch64-darwin x86_64-darwin
      #   '';
      # };
    };
  in
  {
    # Build flake: darwin-rebuild build --flake .#bort
    darwinConfigurations."bort" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "brett";
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
            mutableTaps = false;
            autoMigrate = true; # Disable if new setup
          };
        }
      ];
    };
    darwinPackages = self.darwinConfigurations."bort".pkgs;
  };
}
