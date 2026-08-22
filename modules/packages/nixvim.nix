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
        module = import ./_nixvim/config.nix;
        extraSpecialArgs = {
          inherit pkgs-stable;
          catppuccin = config.seele.catppuccin;
        };
      };
    };
}
