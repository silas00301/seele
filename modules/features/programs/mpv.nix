{
  config,
  lib,
  ...
}:
let
  module = (
    { config, pkgs, ... }:
    {
      programs.mpv = {
        enable = true;
        # Publish playback to the desktop media keys and Seele Now Playing.
        scripts = [ pkgs.mpvScripts.mpris ];

        config = {
          hwdec = "auto-safe";
          keep-open = "yes";
          save-position-on-quit = "yes";
          # The desktop lets output gain reach 150%, so the player that feeds it
          # stops at the same ceiling instead of a lower one of its own.
          volume-max = 150;
          # Portable profiles do not activate XDG user directories; keep that
          # fallback relative to the runtime home rather than the build sentinel.
          # Home Manager encodes the value literally, including spaces and quotes.
          screenshot-directory =
            if config.xdg.userDirs.enable && config.xdg.userDirs.pictures != null then
              config.xdg.userDirs.pictures
            else
              "~/Pictures";
          screenshot-format = "png";
          sub-auto = "fuzzy";
          alang = "jpn,ja,eng,en,deu,de";
          slang = "eng,en,deu,de";
        };

        # Mirror mpv's own arrow keys onto the directional geometry the editor,
        # multiplexer, and window manager already use: horizontal seeks five
        # seconds, vertical a minute. Only lowercase `j` is taken, so `J` keeps
        # cycling subtitle tracks.
        bindings = {
          h = "seek -5";
          l = "seek 5";
          j = "seek -60";
          k = "seek 60";
        };
      };
    }
  );
in
{
  flake.modules.homeManager."mpv" = module;

  seele.portable.mpv = {
    systems = lib.filter (lib.hasSuffix "-linux") config.systems;
  };
}
