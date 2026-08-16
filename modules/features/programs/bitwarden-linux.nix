{ ... }:
let
  module = (
    { username, ... }:
    {
      home.sessionVariables = {
        SSH_AUTH_SOCK = "/home/${username}/.bitwarden-ssh-agent.sock";
      };
    }
  );
in
{
  flake.modules.homeManager."bitwarden-linux" = module;
}
