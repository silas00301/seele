{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        seele-greeter = inputs.seele-shell.packages.${system}.greeter;
      };
    };
}
