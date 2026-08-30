{ ... }:
let
  module = ({
    services.jankyborders = {
      enable = true;
      style = "round";
      width = 2.0;
    };
  });
in
{
  flake.modules.darwin."janky-borders" = module;
}
