{ ... }:
let
  homeModule = (
    { username, ... }:
    {
      home.sessionVariables = {
        SSH_AUTH_SOCK = "/Users/${username}/.bitwarden-ssh-agent.sock";
      };

      programs.chromium.extensions = [
        { id = "nngceckbapebfimnlniiiahkandclblb"; }
      ];
      programs.zen-browser.policies.ExtensionSettings."{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
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
