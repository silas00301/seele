{ ... }:
let
  module = (
    {
      config,
      lib,
      username,
      pkgs,
      ...
    }:
    {
      programs.nh = {
        enable = true;
        flake =
          if pkgs.stdenv.hostPlatform.isLinux then "/home/${username}/seele" else "/Users/${username}/seele";
        clean = {
          enable = true;
          extraArgs = [
            "--keep"
            "3"
            "--keep-since"
            "3d"
          ];
        };
      };

      # Extend Home Manager's existing owner rather than adding another timer.
      # Failed user services are outside the system failure-analysis generator.
      systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        nh-clean = {
          Unit.OnFailure = [ "seele-nh-clean-failed.service" ];
          Service = {
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };
        seele-nh-clean-failed = {
          Unit.Description = "Report failed Nix cleanup";
          Service = {
            Type = "oneshot";
            ExecStart = lib.hm.strings.escapeSystemdExecArgs [
              "${pkgs.libnotify}/bin/notify-send"
              "--app-name=Seele"
              "--icon=dialog-error"
              "--urgency=critical"
              "--"
              "Nix cleanup failed"
              "The nh cleanup did not finish. Inspect journalctl --user -u nh-clean.service before retrying."
            ];
          };
        };
      };

      # launchd does not keep stdout/stderr in the systemd journal. Keep one
      # private log for this same scheduled cleanup, including failure output.
      launchd.agents.nh-clean.config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nh-clean.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nh-clean.log";
        Umask = 63;
      };

      # nh escalates on its own to activate a generation, and its `auto`
      # strategy tries doas, then sudo, before run0 -- so it lands on sudo and
      # prompts on the terminal. Naming run0 explicitly routes that escalation
      # through polkit instead, which is what puts it in the Seele Polkit dialog
      # with the key and the password both available.
      #
      # Left as a bare name rather than a store path on purpose: this picks the
      # running system's run0, and pinning one build of systemd for a privilege
      # escalation path would let it drift from the systemd actually booted.
      # run0 is systemd's, so Darwin keeps nh's own default.
      home.sessionVariables = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        NH_ELEVATION_STRATEGY = "run0";
      };
    }
  );
in
{
  flake.modules.homeManager."nh" = module;
}
