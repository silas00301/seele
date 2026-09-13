{ ... }:
{
  flake.modules.homeManager.codex = {
    programs.codex.enable = true;
  };

  flake.modules.nixos.codex = {
    environment.etc."codex/config.toml".text = ''
      [agents]
      max_concurrent_threads_per_session = 64
    '';
  };
}
