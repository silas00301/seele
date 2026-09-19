{ ... }:
let
  module = ({
    programs.fd = {
      enable = true;
      ignores = [
        "*.bak"
        ".git/"
        ".jj/"
      ];
    };
  });
in
{
  flake.modules.homeManager."fd" = module;

  seele.portable.fd = { };
}
