{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inputReport = pkgs.writeShellApplication {
        name = "seele-inputs";
        text = ''
          exec ${pkgs.python3}/bin/python3 ${./_inputs/report.py} "$@"
        '';
      };
    in
    {
      apps.inputs = {
        type = "app";
        program = "${inputReport}/bin/seele-inputs";
        meta.description = "Inspect local flake input pins and follows without fetching";
      };

      checks.inputs-report = pkgs.runCommand "inputs-report-check" { } ''
        export PYTHONDONTWRITEBYTECODE=1
        ${pkgs.python3}/bin/python3 ${./_inputs}/test-report.py
        touch "$out"
      '';
    };
}
