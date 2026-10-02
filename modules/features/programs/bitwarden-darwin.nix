{ ... }:
let
  homeModule = (
    { username, ... }:
    {
      # ssh reads the agent from IdentityAgent below, which holds in sessions
      # that never inherited this variable. ssh-keygen does not read
      # ssh_config, so Git and Jujutsu SSH signing still find the agent here.
      home.sessionVariables = {
        SSH_AUTH_SOCK = "/Users/${username}/.bitwarden-ssh-agent.sock";
      };

      # The `ssh` feature's `Host *` block, rendered after the local include,
      # so a host entry there can still name another agent.
      programs.ssh.settings."*".IdentityAgent = "~/.bitwarden-ssh-agent.sock";

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
