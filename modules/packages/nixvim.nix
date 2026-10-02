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
      checks.nixvim-refresh =
        pkgs.runCommand "nixvim-refresh"
          {
            nativeBuildInputs = [ pkgs.python3 ];
            NVIM = "${pkgs.neovim-unwrapped}/bin/nvim";
          }
          ''
            python3 ${./_nixvim}/test-refresh.py
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
