{ ... }:
let
  module = ({
    programs.bun = {
      enable = true;
      settings = {
        telemetry = false;
      };
    };
  });
in
{
  flake.modules.homeManager."bun" = module;
}
