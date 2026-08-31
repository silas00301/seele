{ ... }:
let
  module = ({ programs.bottom.enable = true; });
in
{
  flake.modules.homeManager."bottom" = module;

  seele.portable.btm = {
    modules = [ "bottom" ];
    binary = "btm";
  };
}
