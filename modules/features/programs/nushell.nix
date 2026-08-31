{ ... }:
let
  module = ({
    programs.nushell = {
      enable = true;
    };
  });
in
{
  flake.modules.homeManager."nushell" = module;

  seele.portable.nu = {
    modules = [
      "nushell"
      "atuin"
      "direnv"
      "starship"
      "yazi"
      "zoxide"
    ];
    binary = "nu";
  };
}
