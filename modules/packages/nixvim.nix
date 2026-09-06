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
          catppuccin = config.seele.catppuccin;
        };
      };
    };
}
