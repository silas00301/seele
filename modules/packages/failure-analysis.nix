{ inputs, lib, ... }:
{
  perSystem = { system, ... }: {
    packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
      failure-analysis = inputs.seele-shell.packages.${system}.failure-analysis;
    };
  };
}
