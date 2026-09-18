{ ... }:
let
  # `catppuccin-cursors` publishes one output per flavor/accent pair, named
  # `<flavor><Accent>`, and installs it as `catppuccin-<flavor>-<accent>-cursors`
  # below `share/icons`.
  cursorFor =
    {
      catppuccin,
      lib,
      pkgs,
    }:
    let
      variant = "${catppuccin.flavor}${lib.toSentenceCase catppuccin.accent}";
    in
    {
      package = pkgs.catppuccin-cursors.${variant};
      name = "catppuccin-${catppuccin.flavor}-${catppuccin.accent}-cursors";
      size = 24;
    };
  homeModule =
    {
      catppuccin,
      lib,
      pkgs,
      ...
    }:
    let
      cursor = cursorFor { inherit catppuccin lib pkgs; };
    in
    {
      # Stylix owns the pointer even though `stylix.autoEnable` is off, because
      # `stylix.cursor` is not a target: it applies whenever `stylix.enable` is
      # set, and the already active `gtk`, `kde`, and `x11` targets read it to
      # theme GTK, Qt/KDE, and X11 clients. Stylix defines `home.pointerCursor`
      # from it, so defining that option here as well would collide with it.
      stylix.cursor = {
        inherit (cursor) name package size;
      };

      # Hyprland draws its own pointer and reads the theme from its process
      # environment while it parses this configuration, which is earlier than
      # the session variables Home Manager writes for shells. The same values
      # reach the clients the compositor spawns, including XWayland.
      wayland.windowManager.hyprland.settings.env = [
        {
          _args = [
            "XCURSOR_THEME"
            cursor.name
          ];
        }
        {
          _args = [
            "XCURSOR_SIZE"
            (toString cursor.size)
          ];
        }
      ];
    };
  nixosModule =
    {
      catppuccin,
      lib,
      pkgs,
      ...
    }:
    let
      cursor = cursorFor { inherit catppuccin lib pkgs; };
    in
    {
      # The greeter runs as its own user before any Home Manager profile exists,
      # so the theme has to live in the system profile rather than in the user's
      # `~/.icons`. `xdg.icons` links `share/icons` into that profile and keeps
      # it on `XCURSOR_PATH`.
      environment.systemPackages = [ cursor.package ];

      # Clients that never set `XCURSOR_THEME` themselves resolve the `default`
      # theme, which this points at ours for the whole machine.
      xdg.icons.fallbackCursorThemes = [ cursor.name ];

      # `pam_env` exports these to every session, the greeter's included.
      environment.sessionVariables = {
        XCURSOR_THEME = cursor.name;
        XCURSOR_SIZE = toString cursor.size;
      };
    };
in
{
  flake.modules.homeManager.cursor = homeModule;
  flake.modules.nixos.cursor = nixosModule;
}
