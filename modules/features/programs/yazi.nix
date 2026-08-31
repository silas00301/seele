{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;
        shellWrapperName = "y";
        plugins = with pkgs; {
          git = yaziPlugins.git;
          glow = yaziPlugins.glow;
          diff = yaziPlugins.diff;
          chmod = yaziPlugins.chmod;
          lazygit = yaziPlugins.lazygit;
        };
      };
    }
  );
in
{
  flake.modules.homeManager."yazi" = module;

  seele.portable.yazi = {
    modules = [
      "yazi"
      "bat"
      "fd"
      "ripgrep"
      "lazygit"
    ];
  };
}
