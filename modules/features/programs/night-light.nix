{ ... }:
let
  # The desktop is themed for a dark room and then lights it with a 6500K
  # screen anyway. Every other machine the user touches already corrects that
  # after dark -- macOS calls it Night Shift, phones call it something else --
  # and Hyprland has had the piece that does it since it gained the CTM
  # protocol: hyprsunset asks the compositor for a colour transform rather than
  # drawing a shader over the screen, so screenshots, screen shares and the
  # frozen-screen pickers keep the colours they would have had. Hyprland
  # already leaves fullscreen video and game content out of an external
  # transform by itself, and drops the fade on NVIDIA, so neither needs saying
  # here.
  #
  # The schedule is clock times rather than sunrise and sunset, deliberately.
  # Those need coordinates, and coordinates are the user's home address in a
  # public repository; the hour is also what somebody actually notices. Two
  # evening steps instead of one keep the change from arriving as a jolt.
  module =
    { lib, pkgs, ... }:
    let
      systemctl = lib.getExe' pkgs.systemd "systemctl";

      # The service is the state. Stopping hyprsunset drops its transform, and
      # Hyprland resets every output to identity when that client goes away, so
      # the screen comes back to its own colours without anything having to
      # remember that it was tinted. Starting it again applies whichever
      # profile the clock is in. Nothing is persisted, so a session that ends
      # with the filter switched off still starts the next one on schedule.
      toggle = pkgs.writeShellScript "seele-night-light" ''
        set -euo pipefail

        if ${systemctl} --user is-active --quiet hyprsunset.service; then
          exec ${systemctl} --user stop hyprsunset.service
        fi

        exec ${systemctl} --user start hyprsunset.service
      '';
    in
    {
      services.hyprsunset = {
        enable = true;

        settings.profile = [
          # Daylight is the screen's own; `identity` is hyprsunset running and
          # changing nothing rather than hyprsunset being absent.
          {
            time = "7:00";
            identity = true;
          }
          # A nudge rather than a change: at 19:00 it is still daylight for
          # half the year, so this step is meant to pass unnoticed and only be
          # missed once it is gone. 22:00 is the one that is actually warm.
          {
            time = "19:00";
            temperature = 5000;
          }
          {
            time = "22:00";
            temperature = 4000;
          }
        ];
      };

      # Reading a photograph, judging a colour, or showing the screen to
      # somebody is exactly when a warm screen is in the way, and it is also
      # when waiting until 07:00 is not an answer. The session's own target
      # starts the service, so the key can borrow the same switch.
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("${toggle}"), { description = "Toggle the night light" })
      '';
    };
in
{
  flake.modules.homeManager.night-light = module;
}
