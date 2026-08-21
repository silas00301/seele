{ ... }:
let
  homeModule = (
    { username, ... }:
    {
      home.sessionVariables = {
        SSH_AUTH_SOCK = "/Users/${username}/.bitwarden-ssh-agent.sock";
      };
    }
  );
  darwinModule = {
    homebrew.casks = [ "bitwarden" ];
  };
in
{
  flake.modules.homeManager.bitwarden-darwin = homeModule;
  flake.modules.darwin.bitwarden = darwinModule;
}
