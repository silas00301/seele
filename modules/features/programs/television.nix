{ ... }:
let
  module = (
    { selfPackages, ... }: {
      programs.television = {
        enable = true;
        settings = {
          ui.status_bar = {
            separator_open = "";
            separator_close = "";
          };
        };
        channels = {
          files = {
            metadata = {
              name = "files";
              description = "A channel to select files and directories";
              requirements = [
                "fd"
                "bat"
              ];
            };
            source = {
              command = [
                "fd -t f"
                "fd -t f -H"
              ];
            };
            preview = {
              command = "bat -n --color=always '{}'";
            };
            keybindings = {
              shortcut = "f1";
              ctrl-e = "actions:edit";
              ctrl-up = "actions:goto_parent_dir";
            };
            actions = {
              edit = {
                description = "Opens the selected entries with the default editor (falls back to vim)";
                command = "${selfPackages.nixvim}/bin/nvim '{}'";
                shell = "bash";
                mode = "execute";
              };
              goto_parent_dir = {
                description = "Re-opens tv in the parent directory";
                command = "tv files ..";
                mode = "execute";
              };
            };
          };
        };
      };

      programs.nix-search-tv.enable = true;
    }
  );
in
{
  flake.modules.homeManager."television" = module;

  seele.portable.tv = {
    modules = [
      "television"
      "fd"
      "bat"
    ];
    binary = "tv";
  };
}
