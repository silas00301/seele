{ ... }:
let
  module = (
    { username, ... }:
    {

      home.sessionVariables = {
        SSH_AUTH_SOCK = "/home/${username}/.1password/agent.sock";
      };

      programs.ssh = {
        extraConfig = ''
          Host *
            IdentityAgent /home/${username}/.1password/agent.sock
        '';
      };
    }
  );
in
{
  flake.modules.homeManager."1password-linux" = module;
}
