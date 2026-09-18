{ ... }:
{
  flake.modules.homeManager.seele-caffeinate =
    { selfPackages, ... }:
    let
      package = selfPackages.seele-shell;
    in
    {
      # The session is the descriptor this process holds, so the unit's lifetime
      # is the inhibitor's lifetime. Binding it to the graphical session means
      # logging out releases it, and a crash cannot leave the machine awake:
      # the kernel closes the descriptor with the process. Nothing is persisted,
      # so a restarted service comes back with no session rather than restoring
      # an indefinite one.
      systemd.user.services.seele-caffeinate = {
        Unit = {
          Description = "Caffeinate idle inhibitor sessions";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${package}/bin/seele-caffeinate serve";
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = 2;
          NoNewPrivileges = true;
          LimitCORE = 0;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
