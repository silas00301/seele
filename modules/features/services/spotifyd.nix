{ ... }:
let
  module = ({
    services.spotifyd = {
      enable = true;
    };
  });
in
{
  flake.modules.homeManager."spotifyd" = module;
}
