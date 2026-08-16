{ ... }:
let
  module = (
    {
      config,
      pkgs,
      lib,
      ...
    }:

    {
      homebrew.enable = true;

      homebrew.casks = [
        # currently needs manual install because of some bug
        "logi-options+"
        #"obsidian"
        "raycast"
        "elgato-stream-deck"
        "ghostty"
      ];

      security.pam.services.sudo_local.touchIdAuth = true;

      system.primaryUser = config.username;

      users.users.${config.username}.shell = lib.mkForce pkgs.fish;

      nixpkgs = {
        hostPlatform = "aarch64-darwin";
        config = {
          allowUnfree = true;
          allowUnfreePredicate = (_: true);
          permittedInsecurePackages = [ "electron-39.8.10" ];
        };
      };

      nix = {
        enable = true;
        package = pkgs.nix;
      };

      system = {
        defaults = {
          WindowManager = {
            EnableStandardClickToShowDesktop = false;
            EnableTilingByEdgeDrag = false;
            EnableTilingOptionAccelerator = false;
          };
          controlcenter = {
            AirDrop = false;
            BatteryShowPercentage = false;
            Bluetooth = false;
            Display = false;
            FocusModes = false;
            NowPlaying = false;
            Sound = false;
          };
          dock = {
            autohide = true;
            mru-spaces = false;
            magnification = true;
            autohide-time-modifier = 0.2;
            mineffect = "genie";
            show-recents = false;
            expose-group-apps = true;
            autohide-delay = 0.24;
            persistent-apps = [
              "/Users/${config.username}/Applications/Home Manager Apps/Zen Browser (Beta).app/"
              "/Users/${config.username}/Applications/Home Manager Apps/Spotify.app/"
              "/Applications/Ghostty.app/"
            ];
            persistent-others = [
              "/Users/${config.username}/Downloads/"
            ];
          };
          finder = {
            AppleShowAllExtensions = true;
            FXPreferredViewStyle = "clmv";
            ShowPathbar = true;
            ShowStatusBar = true;
          };
          menuExtraClock = {
            Show24Hour = true;
            ShowDate = 0;
            ShowDayOfMonth = true;
          };
          NSGlobalDomain = {
            ApplePressAndHoldEnabled = false;
            NSAutomaticPeriodSubstitutionEnabled = false;
            NSAutomaticCapitalizationEnabled = false;
            NSWindowShouldDragOnGesture = true;
            AppleInterfaceStyle = "Dark";
            "com.apple.keyboard.fnState" = true;
          };
          spaces.spans-displays = false;
          trackpad = {
            Clicking = true;
            Dragging = true;
          };
        };
        keyboard = {
          enableKeyMapping = true;
          remapCapsLockToEscape = true;
        };
        startup.chime = false;
      };
    }
  );
in
{
  flake.modules.darwin."system-darwin" = module;
  flake.modules.darwin."darwin" = module;
}
