{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3.withPackages (p: [ p.jsonschema ]);
    in
    {
      packages.maintenance = pkgs.stdenvNoCC.mkDerivation {
        pname = "seele-maintenance";
        version = "1.0.0";
        src = ./_maintenance;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        dontBuild = true;
        doCheck = true;
        checkPhase = ''
          export PYTHONDONTWRITEBYTECODE=1
          ${python}/bin/python3 test_model.py
          ${python}/bin/python3 test_publishers.py
          ${python}/bin/python3 test_server.py
        '';
        installPhase = ''
          mkdir -p "$out/libexec/seele-maintenance" "$out/bin"
          cp model.py server.py publishers.py "$out/libexec/seele-maintenance/"
          makeWrapper ${python}/bin/python3 "$out/bin/seele-maintenance" \
            --add-flags "$out/libexec/seele-maintenance/server.py" \
            --prefix PATH : ${
              pkgs.lib.makeBinPath [
                pkgs.systemd
                pkgs.openssl
                pkgs.ghostty
                pkgs.libnotify
              ]
            } \
            --suffix PATH : /run/current-system/sw/bin
        '';
        meta.mainProgram = "seele-maintenance";
        meta.platforms = pkgs.lib.platforms.linux;
      };
    };
}
