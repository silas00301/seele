{ config, ... }:
{
  flake.modules.homeManager.nerv.imports = [
    config.flake.modules.homeManager.opencode
    config.flake.modules.homeManager.claude-code
    config.flake.modules.homeManager.proton-vpn
    config.flake.modules.homeManager.openlogi
    config.flake.modules.homeManager.middle-click
    config.flake.modules.homeManager.seele-notes
    config.flake.modules.homeManager.codex-broker
    config.flake.modules.homeManager.seele-shell
    config.flake.modules.homeManager.seele-transfers
    config.flake.modules.homeManager.failure-analysis
    config.flake.modules.homeManager.t3code
  ];
}
