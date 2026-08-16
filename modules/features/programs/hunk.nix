{ ... }:
let
  module = (
    { pkgs, lib, ... }:
    let
      tomlFormat = pkgs.formats.toml { };
    in
    {
      home.packages = [
        pkgs.hunk
      ];

      xdg.configFile."hunk/config.toml".source = tomlFormat.generate "config.toml" {
        theme = "catppuccin-mocha";
        vcs = "jj";
      };

      programs.jujutsu.settings = {
        ui = {
          pager = lib.mkForce [
            "hunk"
            "pager"
          ];
          diff-formatter = lib.mkForce ":git";
        };
      };
    }
  );
in
{
  flake.modules.homeManager."hunk" = module;
}
