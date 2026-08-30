{ config, ... }:
let
  modules = config.flake.modules.darwin;
  module =
    { config, pkgs, ... }:
    {
      imports = [
        modules.stylix
        modules.dock
        modules.finder
        modules.ghostty
        modules.janky-borders
        modules.elgato-stream-deck
        modules.raycast
        modules.logi-options
        modules.homebrew
      ];

      security.pam.services.sudo_local.touchIdAuth = true;

      system.primaryUser = config.username;

      nixpkgs = {
        hostPlatform = "aarch64-darwin";
        config = {
          allowUnfree = true;
          allowUnfreePredicate = (_: true);
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
    };
in
{
  flake.modules.darwin.system-darwin = module;
  flake.modules.darwin.darwin = module;
}
