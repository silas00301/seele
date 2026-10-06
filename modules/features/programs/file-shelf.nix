{ ... }:
{
  flake.modules.homeManager.file-shelf =
    { lib, selfPackages, ... }:
    let
      shellctl = "${selfPackages.seele-shell}/bin/seele-shellctl";
      collect = lib.escapeShellArg ''${shellctl} shelf "$@"'';
    in
    {
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.bind("SUPER + CTRL + SHIFT + E", hl.dsp.exec_cmd("${shellctl} shelf"), {
          description = "Open the temporary file shelf",
        })
      '';
      programs.yazi.keymap.mgr.prepend_keymap = [
        {
          on = "<A-s>";
          run = "shell ${collect}";
          desc = "Collect hovered or selected files in the temporary shelf";
        }
      ];
    };
}
