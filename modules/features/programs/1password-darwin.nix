{ ... }:
let
  module = (
    { username, ... }:
    {

      home.sessionVariables = {
        SSH_AUTH_SOCK = "/Users/${username}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
      };
    }
  );
in
{
  flake.modules.homeManager."1password-darwin" = module;
}
