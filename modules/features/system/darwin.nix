{ config, ... }:
let
  modules = config.flake.modules.darwin;
  module =
    { config, ... }:
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

      # Terminals here run inside tmux, whose server has left the GUI
      # login's bootstrap namespace, so pam_tid could not reach Touch ID and
      # sudo fell straight through to the password. `reattach` puts
      # pam_reattach ahead of pam_tid in /etc/pam.d/sudo_local to move sudo
      # back into that session first. Over SSH pam_tid still declines and the
      # password follows. `watchIdAuth` stays off: pam-watchid has no remote
      # session check of its own, so it would let a wrist approve an SSH sudo.
      security.pam.services.sudo_local = {
        touchIdAuth = true;
        reattach = true;
      };

      system.primaryUser = config.username;

      nixpkgs = {
        hostPlatform = "aarch64-darwin";
        config = {
          allowUnfree = true;
          allowUnfreePredicate = (_: true);
        };
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
