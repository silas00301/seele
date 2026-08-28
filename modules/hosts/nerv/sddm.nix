{ ... }:
let
  # Preserved as a named module but intentionally dormant while greetd and
  # Seele Greeter owns login. Nothing imports `nerv-sddm`, so none of this reaches the
  # host; restoring SDDM means importing it from the `nerv` aggregate again and
  # dropping `nerv-greetd`, because two display managers cannot both claim vt1.
  #
  # The Catppuccin theming lives here rather than in the shared theme feature so
  # the dormant module carries everything SDDM needs to come back intact, and so
  # an inactive display manager cannot pull its theme into the system closure.
  module = {
    catppuccin.sddm.enable = true;

    services.displayManager = {
      defaultSession = "hyprland";
      sddm = {
        enable = true;
        settings.Users.RememberLastSession = false;
        wayland.enable = true;
      };
    };
  };
in
{
  flake.modules.nixos.nerv-sddm = module;
}
