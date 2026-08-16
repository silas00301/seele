{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      programs.rofi = {
        enable = true;
        plugins = [
          pkgs.rofi-calc
          pkgs.rofi-pulse-select
          pkgs.rofi-emoji
          pkgs.rofi-obsidian
        ];
        extraConfig = {
          combi-modes = [
            "window"
            "drun"
            "calc"
          ];
          modes = [
            "calc"
            "window"
            "drun"
            "combi"
          ];
        };
        font = pkgs.maple-mono.NF-CN.name;
      };
    }
  );
in
{
  flake.modules.homeManager."rofi" = module;
}
