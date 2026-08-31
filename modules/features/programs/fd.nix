{ ... }:
let
  module = ({
    programs.fd = {
      enable = true;
      ignores = [
        "*.bak"
        ".git/"
      ];
    };
  });
in
{
  flake.modules.homeManager."fd" = module;

  seele.portable.fd = { };
}
