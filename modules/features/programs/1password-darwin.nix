{ ... }:
let
  module = (
    { username, ... }:
    {
      # ssh reads the agent from IdentityAgent below, which holds in sessions
      # that never inherited this variable. ssh-keygen does not read
      # ssh_config, so Git and Jujutsu SSH signing still find the agent here.
      home.sessionVariables = {
        SSH_AUTH_SOCK = "/Users/${username}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
      };

      # The `ssh` feature's `Host *` block, rendered after the local include,
      # so a host entry there can still name another agent. ssh_config splits
      # arguments on whitespace, so the space in `Group Containers` needs the
      # quotes; ssh strips them before expanding `~`.
      programs.ssh.settings."*".IdentityAgent =
        ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
    }
  );
in
{
  flake.modules.homeManager."1password-darwin" = module;
}
