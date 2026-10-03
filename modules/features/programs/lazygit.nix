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
    modules = [
      "lazygit"
      "git"
      "bat"
    ];
  };
}
