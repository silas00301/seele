{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      shellAi = inputs.seele-shell.packages.${system}.shell-ai;
    in
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        shell-ai = shellAi;
      };
      checks = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        shell-ai = shellAi;
      };
    };
}
