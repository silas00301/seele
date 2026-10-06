{ ... }:
{
  flake.modules.homeManager.ssh-keepalive =
    { lib, ... }:
    {
      programs.ssh = {
        enable = true;
        # Use OpenSSH defaults, then add only these fallback values. Home
        # Manager emits its '*' block after specific hosts and Includes.
        enableDefaultConfig = false;
        settings."*" = {
          ServerAliveInterval = lib.mkDefault 60;
          ServerAliveCountMax = lib.mkDefault 3;
        };
      };
    };
}
