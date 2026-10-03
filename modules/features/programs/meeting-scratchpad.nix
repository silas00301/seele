{ config, lib, ... }:
let
  event = config.seele.meetingScratchpad.event;
  configured = event.id != "" || event.title != "";
  module =
    { pkgs, selfPackages, ... }:
    let
      # The note is a local file on this machine. The opener only accepts a
      # markdown file under the meeting state directory, and the calendar
      # worker passes that path. Ghostty's `-e` keeps this window from joining
      # another Ghostty, including the terminal scratchpad.
      opener = pkgs.writeShellScriptBin "seele-meeting-scratchpad" ''
        set -eu
        path=''${1:?}
        root="''${XDG_STATE_HOME:-$HOME/.local/state}/seele-meetings"
        case "$path" in
          "$root"/*.md) ;;
          *) printf '%s\n' "seele-meeting-scratchpad: refusing a path outside meeting notes" >&2
             exit 1 ;;
        esac
        [ -f "$path" ]
        exec ${pkgs.ghostty}/bin/ghostty \
          --class=org.seele.meeting-scratchpad \
          -e ${selfPackages.nixvim}/bin/nvim -- "$path"
      '';
    in
    {
      home.packages = [ opener ];

      xdg.configFile = lib.mkIf configured {
        "seele-shell/meeting-scratchpad.json".text = builtins.toJSON {
          inherit (event) id title;
          opener = "${opener}/bin/seele-meeting-scratchpad";
        };
      };

      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.window_rule({
          match = {
            class = [[^org\.seele\.meeting-scratchpad$]],
          },
          float = true,
          size = { "monitor_w*0.6", "monitor_h*0.55" },
          center = true,
        })
      '';
    };
in
{
  options.seele.meetingScratchpad.event = {
    id = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Google Calendar id of the one recurring meeting that opens a local
        scratchpad on nerv. An instance id of the form
        `<id>_YYYYMMDDTHHMMSSZ` also matches. Empty disables the id match.
      '';
    };

    title = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Exact event title. Used on its own, or together with `id`. Empty
        disables the title match. With both empty, no scratchpad is configured.
      '';
    };
  };

  config.flake.modules.homeManager.meeting-scratchpad = module;
}
