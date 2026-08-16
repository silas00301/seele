{ ... }:
let
  module = (
    {
      pkgs,
      spicetify-nix,
      catppuccin,
      ...
    }:
    let
      spicePkgs = spicetify-nix.legacyPackages.${pkgs.system};
    in
    {
      programs.spicetify = {
        enable = true;

        theme = spicePkgs.themes.catppuccin;
        colorScheme = catppuccin.flavor;
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
