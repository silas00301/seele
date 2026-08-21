{ ... }:
let
  module =
    { config, ... }:
    {
      system.defaults.dock = {
        autohide = true;
        mru-spaces = false;
        magnification = true;
        autohide-time-modifier = 0.2;
        mineffect = "genie";
        show-recents = false;
        expose-group-apps = true;
        autohide-delay = 0.24;
        persistent-apps = [
          "/Users/${config.username}/Applications/Home Manager Apps/Zen Browser (Beta).app/"
          "/Users/${config.username}/Applications/Home Manager Apps/Spotify.app/"
          "/Applications/Ghostty.app/"
        ];
        persistent-others = [
          "/Users/${config.username}/Downloads/"
        ];
      };
    };
in
{
  flake.modules.darwin.dock = module;
}
