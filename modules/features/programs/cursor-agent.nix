{ ... }:
{
  flake.modules.homeManager.cursor-agent = { pkgs, ... }: {
    home.packages = [ pkgs.cursor-cli ];
  };

  seele.portable.cursor-agent = {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
