{ ... }:
let
  module = ({
    programs.sesh = {
      enable = true;
      settings = {
        session = [
          {
            name = "dotfiles";
            path = "~/dotfiles";
            startup_script = "nvim";
            preview_command = "jj log -r 'all()' --no-pager";
            windows = [ "jj" ];
          }
        ];
        window = [
          {
            name = "jj";
            startup_script = "jj";
          }
        ];
      };
    };
  });
in
{
  flake.modules.homeManager."sesh" = module;
}
