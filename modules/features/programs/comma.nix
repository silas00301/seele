{ ... }:
let
  module = ({
    programs.nix-index-database.comma.enable = true;
    programs.nix-index.enable = true;
  });
in
{
  flake.modules.homeManager."comma" = module;
}
