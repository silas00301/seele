{ ... }:
let
  module = (
    { username, ... }:
    {

      home.sessionVariables = {
        SSH_AUTH_SOCK = "/home/${username}/.1password/agent.sock";
      };

      programs = {
        chromium.extensions = [
          { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; }
        ];
        ssh.extraConfig = ''
          Host *
            IdentityAgent /home/${username}/.1password/agent.sock
        '';
        zen-browser.policies.ExtensionSettings."{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
        };
      };
    }
  );
in
{
  flake.modules.homeManager."1password-linux" = module;
}
