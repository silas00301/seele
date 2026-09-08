{ lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      shellAi = pkgs.writeShellApplication {
        name = "seele-shell-ai";
        runtimeInputs = [
          pkgs.fzf
          pkgs.pi-coding-agent
        ];
        text = ''
          exec ${pkgs.python3}/bin/python3 ${./_shell-ai/shell_ai.py} "$@"
        '';
      };
    in
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        shell-ai = shellAi;
      };

      checks = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        shell-ai = pkgs.runCommand "shell-ai-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          export PYTHONDONTWRITEBYTECODE=1
          python3 ${./_shell-ai/test_shell_ai.py} \
            ${./_shell-ai/shell_ai.py} \
            ${../features/programs/shell-ai.nix}
          touch "$out"
        '';
      };
    };
}
