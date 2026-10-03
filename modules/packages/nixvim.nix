{ config, inputs, ... }:
{
  perSystem =
    {
      pkgs,
      pkgs-stable,
      system,
      ...
    }:
    {
      checks.nixvim-whitespace =
        pkgs.runCommand "seele-nixvim-whitespace-check"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.neovim-unwrapped
            ];
          }
          ''
            cp ${./_nixvim/trim-whitespace.lua} trim-whitespace.lua
            cp ${./_nixvim/test-trim-whitespace.py} test-trim-whitespace.py
            python3 test-trim-whitespace.py
            touch "$out"
          '';

      packages.nixvim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
        module = {
          imports = [ ./_nixvim/config.nix ];
          nixpkgs.source = inputs.nixpkgs;
        };
        extraSpecialArgs = {
          inherit pkgs-stable;
          catppuccinPalette = inputs.catppuccin.packages.${system}.palette;
          catppuccin = config.seele.catppuccin;
        };
      };
    };
}
