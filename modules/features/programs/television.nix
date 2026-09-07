{ ... }:
let
  module = (
    { selfPackages, pkgs, ... }:
    let
      projectText = pkgs.writeShellApplication {
        name = "seele-project-text";
        runtimeInputs = [
          pkgs.python3
          pkgs.ripgrep
          pkgs.bat
          selfPackages.nixvim
        ];
        text = ''
          exec python3 ${./_television/text.py} "$@"
        '';
      };
    in
    {
      programs.television = {
        enable = true;
        extraPackages = [
          pkgs.fd
          pkgs.bat
          pkgs.ripgrep
          projectText
        ];
        settings = {
          ui.status_bar = {
            separator_open = "";
            separator_close = "";
          };
        };
        channels = {
          project-text = {
            metadata = {
              name = "project-text";
              description = "Search project text and open a matching line";
              requirements = [ "seele-project-text" ];
            };
            source = {
              command = [
                "seele-project-text source"
                "seele-project-text source --hidden"
              ];
              display = "{split:\\t:2}";
              output = "{split:\\t:2}";
              frecency = false;
            };
            preview = {
              command = "seele-project-text preview '{split:\\t:0}' '{split:\\t:1}'";
              offset = "{split:\\t:1}";
            };
            keybindings = {
              shortcut = "f2";
              enter = "actions:edit";
              ctrl-e = "actions:edit";
            };
            actions.edit = {
              description = "Open the match in Neovim";
              command = "seele-project-text edit '{split:\\t:0}' '{split:\\t:1}'";
              shell = "bash";
              mode = "execute";
            };
          };
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

  perSystem = { pkgs, ... }: {
    checks.television-text =
      pkgs.runCommand "television-text-check"
        {
          nativeBuildInputs = [ pkgs.ripgrep ];
        }
        ''
          export PYTHONDONTWRITEBYTECODE=1
          ${pkgs.python3}/bin/python3 ${./_television}/test_text.py
          touch "$out"
        '';
  };

  seele.portable.tv = {
    modules = [
      "television"
      "fd"
      "bat"
    ];
    binary = "tv";
  };
}
