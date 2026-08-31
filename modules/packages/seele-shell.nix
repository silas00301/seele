{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        seele-shell = inputs.seele-shell.packages.${system}.default;
      };
    };
}
