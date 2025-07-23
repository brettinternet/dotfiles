{ pkgs, ... }: {
  system.defaults = {
    dock.autohide = true;
    dock.persistent-apps = [];
    finder.AppleShowAllExtensions = true;
    finder._FXShowPosixPathInTitle = true;
    finder.FXPreferredViewStyle = "clmv";
    loginwindow.GuestEnabled = false;
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.InitialKeyRepeat = 14;
    NSGlobalDomain.KeyRepeat = 1;
  };
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  programs.zsh.enable = true;
  # Read changelog before upgrading: darwin-rebuild changelog
  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";
  time.timeZone = "America/Denver";

    # Search packages: nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    asdf
    atuin
    bat
    btop
    coreutils
    elixir
    fd
    git
    go-task
    lsd
    mas
    neovim
    qrencode
    rustc
    terminal-notifier
    tmux
    trash-cli
    wget
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
      "discord"
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

  nix.extraOptions = ''
    extra-platforms = aarch64-darwin x86_64-darwin
    experimental-features = nix-command flakes
  '';
}
