{ ... }:
{
  perSystem = { pkgs, ... }: {
    packages.spt-st = pkgs.writeShellScriptBin "spt-st" ./_spt-st/spotify-status.sh;
  };
}
