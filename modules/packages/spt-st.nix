{ ... }:
{
  perSystem = { config, pkgs, ... }: {
    packages.spt-st = pkgs.runCommand "spt-st" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
      mkdir -p "$out/bin"
      makeWrapper ${config.packages.desktop-tools}/bin/spt-st "$out/bin/spt-st" \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.spotify-player ]}
    '';
  };
}
