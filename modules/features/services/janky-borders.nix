{ ... }:
let
  module = ({
    services.jankyborders = {
      enable = true;
      settings = {
        style = "round";
        active_color = "0xffb4befe";
        inactive_color = "0xff6c7086";
        width = 8.0;
      };
    };
  });
in
{
  flake.modules.homeManager."janky-borders" = module;
}
