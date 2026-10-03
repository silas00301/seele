{ ... }:
let
  module = ({
    programs.lazygit = {
      enable = true;
      settings = {
        git.commit.signOff = true;
        os.editPreset = "nvim";
      };
    };
  });
in
{
  flake.modules.homeManager."lazygit" = module;

  seele.portable.lazygit = {
    # The nvim edit preset needs the configured editor in this standalone
    # profile, including its EDITOR value, rather than a foreign host's PATH.
    modules = [
      "lazygit"
      "nixvim"
      "git"
      "bat"
    ];
  };
}
