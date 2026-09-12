{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3.withPackages (p: [ p.jsonschema ]);
    in
    {
      packages.codex-broker = pkgs.stdenvNoCC.mkDerivation {
        pname = "seele-codex-broker";
        version = "1.0.0";
        src = ./_codex-broker;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        dontBuild = true;
        doCheck = true;
        checkPhase = ''
          PYTHONDONTWRITEBYTECODE=1 ${python}/bin/python3 test_broker.py
          PYTHONDONTWRITEBYTECODE=1 ${python}/bin/python3 test_health.py
          SEELE_BROKER_CODEX=${pkgs.codex}/bin/codex PYTHONDONTWRITEBYTECODE=1 ${python}/bin/python3 test_codex.py
        '';
        installPhase = ''
          mkdir -p "$out/libexec/seele-codex-broker" "$out/bin"
          cp broker.py runner.py health.py "$out/libexec/seele-codex-broker/"
          makeWrapper ${python}/bin/python3 "$out/bin/seele-codex" \
            --add-flags "$out/libexec/seele-codex-broker/broker.py" \
            --set SEELE_BROKER_CODEX ${pkgs.codex}/bin/codex
          makeWrapper ${python}/bin/python3 "$out/bin/seele-codex-health" \
            --add-flags "$out/libexec/seele-codex-broker/health.py" \
            --set SEELE_BROKER_CODEX ${pkgs.codex}/bin/codex
        '';
        meta.mainProgram = "seele-codex";
        meta.platforms = pkgs.lib.platforms.linux;
      };
    };
}
