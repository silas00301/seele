{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        codex-broker = inputs.seele-shell.packages.${system}.codex-broker;
      };
    };
}
