{ ... }:
let
  module =
    { lib, selfPackages, ... }:
    let
      zoom = arguments: "${selfPackages.seele-shell}/bin/seele-shellctl zoom ${arguments}";
    in
    {
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        -- Hyprland magnifies the output under the pointer by cursor:zoom_factor
        -- and keeps the pointer in view as it moves. The helper reads the
        -- factor back from Hyprland on every step, so the compositor stays the
        -- only record of it. Nothing resets it at login: a new session, like a
        -- configuration reload, starts at Hyprland's default of 1.
        --
        -- A scroll notch moves a quarter octave and a key half of one, both on
        -- one grid from 1x to 8x, so stepping down always lands on exactly 1.
        -- Hyprland lets one wheel bind through per binds:scroll_event_delay,
        -- 300 ms by default, which also keeps a high-resolution wheel from
        -- turning one notch into several steps.
        --
        -- Under the German layout `=` is Shift + 0, and binds match the
        -- unshifted symbol, so the dedicated + key zooms in beside - and 0.
        -- All of them work while locked: the lock screen is magnified with
        -- everything else, and must never be stranded out of view.
        hl.bind("SUPER + mouse_up", hl.dsp.exec_cmd("${zoom "in --fine"}"), {
          locked = true,
          description = "Zoom in around the pointer",
        })
        hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd("${zoom "out --fine"}"), {
          locked = true,
          description = "Zoom out around the pointer",
        })
        hl.bind("SUPER + plus", hl.dsp.exec_cmd("${zoom "in"}"), {
          locked = true,
          repeating = true,
          description = "Zoom in around the pointer",
        })
        hl.bind("SUPER + minus", hl.dsp.exec_cmd("${zoom "out"}"), {
          locked = true,
          repeating = true,
          description = "Zoom out around the pointer",
        })
        hl.bind("SUPER + 0", hl.dsp.exec_cmd("${zoom "reset"}"), {
          locked = true,
          description = "Reset the screen zoom",
        })
      '';
    };
in
{
  flake.modules.homeManager.screen-zoom = module;
}
