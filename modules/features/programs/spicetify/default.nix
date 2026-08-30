{ ... }:
let
  module = (
    {
      pkgs,
      spicetify-nix,
      ...
    }:
    let
      spicePkgs = spicetify-nix.legacyPackages.${pkgs.system};
    in
    {
      programs.spicetify = {
        enable = true;

        experimentalFeatures = true;
        windowManagerPatch = true;

        enabledExtensions = [
          {
            name = "setAccent.js";
            src = ./js;
          }
        ];
      };
    }
  );
in
{
  flake.modules.homeManager."spicetify" = module;
}
