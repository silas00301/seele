{ ... }:
let
  module = (
    {
      pkgs,
      spicetify-nix,
      ...
    }:
    let
      spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      programs.spicetify = {
        enable = true;

        experimentalFeatures = true;
        windowManagerPatch = true;

        enabledExtensions = [
          {
            name = "syncTheme.js";
            src = ./js;
          }
        ];
      };
    }
  );
in
{
  flake.modules.homeManager."spicetify" = module;
  perSystem = { pkgs, ... }: {
    checks.spicetify-theme =
      pkgs.runCommand "spicetify-theme-check" { nativeBuildInputs = [ pkgs.nodejs ]; }
        ''
          node ${./js/test-syncTheme.cjs} ${./js/syncTheme.js}
          touch "$out"
        '';
  };
}
