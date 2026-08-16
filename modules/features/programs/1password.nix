{ ... }:
let
  module = ({
    programs._1password-shell-plugins = {
      enable = true;

      package = null;
    };
  });
in
{
  flake.modules.homeManager."1password" = module;
}
