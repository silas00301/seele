{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        seele-lock = inputs.seele-shell.packages.${system}.lock;
      };
    };
}
