{ ... }:
let
  module = ({
    programs.lazygit = {
      enable = true;
      settings = {
        paging = {
          colorArg = "always";
        };
        commit.signOff = true;
        os.editPreset = "nvim";
      };
    };
  });
in
{
  flake.modules.homeManager."lazygit" = module;
}
