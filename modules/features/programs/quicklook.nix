{ ... }:
let
  module = (
    {
      lib,
      selfPackages,
      ...
    }:
    let
      shellctl = "${selfPackages.seele-shell}/bin/seele-shellctl";
      # Yazi splits `run` the way a shell would, so the whole template is one
      # quoted argument and the file names stay in the positional parameters
      # Yazi puts them in. Nothing here is interpolated into a command line.
      preview = lib.escapeShellArg ''${shellctl} quicklook "$@"'';
    in
    {
      programs.yazi.keymap.mgr.prepend_keymap = [
        {
          on = "<Space>";
          run = "shell ${preview}";
          desc = "Quick Look the hovered or selected files";
        }
        {
          # Yazi's own Space, moved rather than removed. `[mgr]` and `[input]`
          # are separate layers, so taking Space here never reaches a prompt --
          # which is exactly why Yazi can answer the macOS gesture at all.
          # Ctrl + Space needs a terminal that reports it apart from NUL; both
          # Ghostty and the configured tmux (`extended-keys on`, `csi-u`) do.
          # Visual mode and `<C-a>`/`<C-r>` remain the way to select without it.
          on = "<C-Space>";
          run = [
            "toggle"
            "arrow 1"
          ];
          desc = "Toggle the current selection state";
        }
      ];
    }
  );
in
{
  # Deliberately its own feature rather than part of `yazi`: the file manager
  # is cross-platform and has a portable application, while this binding needs
  # Seele Shell. An unmanaged machine keeps Yazi's upstream Space.
  flake.modules.homeManager."quicklook" = module;
}
