{ ... }:
let
  module = ({
    programs.ripgrep = {
      enable = true;
      # --hidden should reveal project dotfiles, not the VCS object stores.
      # Use --no-config for deliberate metadata inspection.
      arguments = [
        "--glob=!.git"
        "--glob=!.jj"
      ];
    };
  });
in
{
  flake.modules.homeManager."ripgrep" = module;

  seele.portable.rg = {
    modules = [ "ripgrep" ];
    binary = "rg";
  };
}
