{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        seele-polkit = inputs.seele-shell.packages.${system}.polkit;
      };
    };
}
