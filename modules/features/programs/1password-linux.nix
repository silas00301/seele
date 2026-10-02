{ ... }:
let
  module = (
    { username, ... }:
    {
      # ssh reads the agent from IdentityAgent below, which holds in sessions
      # that never inherited this variable. ssh-keygen does not read
      # ssh_config, so Git and Jujutsu SSH signing still find the agent here.
      home.sessionVariables = {
        SSH_AUTH_SOCK = "/home/${username}/.1password/agent.sock";
      };

      programs = {
        chromium.extensions = [
          { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; }
        ];
        # The `ssh` feature's `Host *` block, rendered after the local include,
        # so a host entry there can still name another agent.
        ssh.settings."*".IdentityAgent = "~/.1password/agent.sock";
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
