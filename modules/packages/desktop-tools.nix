{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.desktop-tools = inputs.seele-shell.lib.mkNativePackage {
      inherit pkgs;
      name = "desktop-tools";
    };
    packages.repo-tools = inputs.seele-shell.lib.mkNativePackage {
      inherit pkgs;
      name = "repo-tools";
    };
  };
}
