{
  config,
  lib,
  ...
}:
let
  module = (
    { ... }:
    {
      programs.mpv = {
        enable = true;

        config = {
          hwdec = "auto-safe";
          keep-open = "yes";
          save-position-on-quit = "yes";
          # The desktop lets output gain reach 150%, so the player that feeds it
          # stops at the same ceiling instead of a lower one of its own.
          volume-max = 150;
          screenshot-directory = "~/Pictures";
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
