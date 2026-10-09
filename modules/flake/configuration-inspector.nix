{ ... }:
{
  perSystem = { config, pkgs, ... }: {
    checks.configuration-inspector-catalog = pkgs.writeText "seele-inspector-catalog.json" (
      builtins.toJSON (
        import ../features/programs/_configuration-inspector/test-catalog.nix { lib = pkgs.lib; }
      )
    );
    apps.inspect = {
      type = "app";
      program = "${config.packages.config-tools}/bin/seele-inspect";
      meta.description = "Search the managed host's declared configuration and open its source";
    };
  };
}
