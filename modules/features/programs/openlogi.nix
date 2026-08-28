{ ... }:
let
  homeModule =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.openlogi ];

      # OpenLogi owns `openlogi-agent.service` when its mutable launch-at-login
      # setting is enabled. Keep the declarative service under a separate name
      # so the application cannot rewrite or remove Home Manager's unit.
      systemd.user.services.seele-openlogi-agent = {
        Unit = {
          Description = "OpenLogi background agent";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.openlogi}/bin/openlogi-agent";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  nixosModule =
    { pkgs, username, ... }:
    {
      hardware.uinput.enable = true;
      services.udev.packages = [ pkgs.openlogi ];
      users.users.${username}.extraGroups = [ "uinput" ];
    };
in
{
  flake.modules.homeManager.openlogi = homeModule;
  flake.modules.nixos.openlogi = nixosModule;
}
