{ ... }:
{
  perSystem = { pkgs, ... }: {
    checks.backup-module = pkgs.writeText "seele-backup-module-check.json" (builtins.toJSON (
      import ../features/system/_backups/test-module.nix { inherit (pkgs) lib; }
    ));
  };
}
