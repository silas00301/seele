{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.config-tools = inputs.seele-shell.lib.mkNativePackage {
      inherit pkgs;
      name = "config-tools";
    };
  };
}
