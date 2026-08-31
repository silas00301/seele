{ ... }:
let
  module = ({ programs.ripgrep.enable = true; });
in
{
  flake.modules.homeManager."ripgrep" = module;

  seele.portable.rg = {
    modules = [ "ripgrep" ];
    binary = "rg";
  };
}
