{ config, inputs, ... }:
{
  perSystem =
    {
      pkgs-stable,
      system,
      ...
    }:
    {
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
