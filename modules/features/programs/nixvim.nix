{ ... }:
let
  module = (
    { selfPackages, ... }:
    {
      home.packages = [
        selfPackages.nixvim
      ];

      home.sessionVariables = {
        EDITOR = "${selfPackages.nixvim}/bin/nvim";
      };
    }
  );
in
{
  flake.modules.homeManager."nixvim" = module;
}
