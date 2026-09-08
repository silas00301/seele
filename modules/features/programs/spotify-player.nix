{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      # The shared Catppuccin module supplies the selected flavor.
      programs.spotify-player.enable = true;

      home.packages = [
        pkgs.librespot
      ];
    }
  );
in
{
  flake.modules.homeManager."spotify-player" = module;

  seele.portable.spotify-player = {
    binary = "spotify_player";
  };
}
