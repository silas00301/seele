{ ... }:
let
  module = (
    { username, ... }:
    {
      # ssh reads the agent from IdentityAgent below, which holds in sessions
      # that never inherited this variable. ssh-keygen does not read
      # ssh_config, so Git and Jujutsu SSH signing still find the agent here.
      home.sessionVariables = {
        SSH_AUTH_SOCK = "/home/${username}/.bitwarden-ssh-agent.sock";
      };

      # The `ssh` feature's `Host *` block, rendered after the local include,
      # so a host entry there can still name another agent.
      programs.ssh.settings."*".IdentityAgent = "~/.bitwarden-ssh-agent.sock";
    }
  );
in
{
  flake.modules.homeManager."bitwarden-linux" = module;
}
