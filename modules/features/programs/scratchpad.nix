{ ... }:
let
  module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Ghostty carries a quick terminal of its own, and `ghostty.nix` already
      # binds it on macOS, but neither half of that reaches `nerv` on the
      # versions this flake pins. The `+toggle-quick-terminal` IPC action a
      # compositor binding would call arrives in Ghostty 1.4.0 and nixpkgs is on
      # 1.3.1, and letting Ghostty hold the key itself through a `global:` bind
      # wants global-shortcut plumbing that Hyprland 0.55.4 does not answer.
      # Hyprland already owns a hidden workspace and every key on the keyboard,
      # so let it own the gesture. What appears is still Ghostty.
      #
      # `-e` makes Ghostty start a process of its own instead of joining the
      # running one, which is what lets this window carry a class the rule below
      # can match. tmux is what makes it a scratchpad rather than one more
      # terminal: the session outlives the window, so closing it by accident
      # costs nothing and the next summon opens where the last one stopped.
      terminal = pkgs.writeShellScript "seele-scratchpad" ''
        exec ${pkgs.ghostty}/bin/ghostty \
          --class=org.seele.scratchpad \
          -e ${config.programs.tmux.package}/bin/tmux new-session -A -s scratch
      '';
    in
    {
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        -- A special workspace stays hidden until it is asked for and keeps its
        -- windows while it is away, so the terminal survives being dismissed
        -- without spending one of the numbered workspaces. Hyprland runs the
        -- command whenever it finds the workspace empty, which covers the first
        -- summon and the one after the window was closed alike, so nothing here
        -- has to track whether the terminal is already running.
        hl.workspace_rule({
          workspace = "special:scratchpad",
          on_created_empty = "${terminal}",
        })

        -- Centered rather than dropped from the top edge: the shell's bar owns
        -- the top of the output, and a window rule positions in monitor
        -- coordinates that know nothing about the space that bar reserves, so
        -- anchoring to the top would mean copying the bar's height in here and
        -- keeping the two in step. Centered is also how the quick AI prompt
        -- arrives, which is the other surface that appears in place over
        -- whatever is already on screen.
        hl.window_rule({
          match = {
            class = [[^org\.seele\.scratchpad$]],
          },
          float = true,
          size = { "monitor_w*0.6", "monitor_h*0.55" },
          center = true,
        })

        -- The key left of the 1, which is where macOS summons Ghostty's own
        -- quick terminal from. Hyprland resolves binds against the US keymap
        -- unless `resolve_binds_by_sym` says otherwise, so GRAVE keeps naming
        -- that physical key under the German layout this machine types in.
        hl.bind(
          "SUPER + GRAVE",
          hl.dsp.workspace.toggle_special("scratchpad"),
          { description = "Toggle the scratchpad terminal" }
        )
      '';
    };
in
{
  flake.modules.homeManager.scratchpad = module;
}
