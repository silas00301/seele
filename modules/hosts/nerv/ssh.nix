{ ... }:
let
  module =
    { config, ... }:
    {
      users.users.${config.username}.openssh.authorizedKeys.keys = [
        # Snapshot of https://github.com/silas00301.keys
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPViOU8+CC3RPIs8PAZyHaJYr+oXXNBPw2kAT/zeE9SJ"
      ];

      services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          AllowUsers = [ config.username ];
          AuthenticationMethods = "publickey";
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          PubkeyAuthentication = true;
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
    };
in
{
  flake.modules.nixos.nerv-ssh = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
