{ ... }:
let
  module = (
    { username, pkgs, ... }:
    {
      programs.nh = {
        enable = true;
        flake =
          if pkgs.lib.hasSuffix "-linux" pkgs.system then
            "/home/${username}/dotfiles"
          else
            "/Users/${username}/dotfiles";
        clean = {
          enable = true;
          extraArgs = "--keep 3 --keep-since 3d";
        };
      };
    }
  );
in
{
  flake.modules.homeManager."nh" = module;
}
