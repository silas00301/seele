{ ... }:
let
  homeModule =
    { config, lib, ... }:
    {
      programs.fish = {
        enable = true;
        functions = {
          gitignore = "curl -sL https://www.toptal.com/developers/gitignore/api/$argv";
          mkcd = {
            description = "Create and enter one directory";
            body = ''
              if test (count $argv) -ne 1; or test -z "$argv[1]"
                printf 'Usage: mkcd DIRECTORY\n' >&2
                return 2
              end
              # An absolute path also keeps `cd -` and CDPATH from changing
              # the meaning of the directory that mkdir just created.
              set -l target "$argv[1]"
              if not string match -q '/*' -- "$target"
                set target "$PWD/$target"
              end
              command mkdir -p -- "$target"; and builtin cd -- "$target"
            '';
          };
          croot = {
            description = "Jump to the Jujutsu workspace or Git worktree root";
            body = builtins.readFile ./_fish/croot.fish;
          };
          last_history_item = "echo $history[1]";
          edit = "$EDITOR $argv";
        };
        shellAliases = {
          ls = "eza -la --git";
          l1 = "eza -1 --icons=never";
          jjn = "jj --no-pager";
        }
        // lib.optionalAttrs config.programs.zellij.enable {
          zf = "zellij run -f --";
        }
        // lib.optionalAttrs config.programs.tmux.enable {
          tf = "tmux display-popup -E";
        };
        shellAbbrs = {
          "!!" = {
            position = "anywhere";
            function = "last_history_item";
          };

        };
        shellInit = ''
          set fish_greeting
        '';
        interactiveShellInit = ''
          set -g fish_key_bindings fish_vi_key_bindings

          for script in ~/scripts/*.fish
            source $script
          end

          if not set -q TMUX
            tv sesh
          end
        '';
      };
    };
  homeDarwinModule =
    { lib, ... }:
    {
      programs.fish = {
        shellInit = lib.mkAfter ''
          eval "$(/opt/homebrew/bin/brew shellenv)" 
        '';
        shellAbbrs.rebuild = {
          position = "command";
          expansion = "nh darwin switch -H asuka";
        };
      };
    };
  homeLinuxModule = {
    programs.fish.shellAbbrs.sudo = {
      position = "command";
      expansion = "run0";
    };

    programs.fish.shellAbbrs.rebuild = {
      position = "command";
      expansion = "nh os switch";
    };
  };
  systemModule = {
    programs.fish = {
      enable = true;
      useBabelfish = true;
    };
  };
  darwinSystemModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ systemModule ];
      users.users.${config.username}.shell = lib.mkForce pkgs.fish;
    };
in
{
  flake.modules.homeManager = {
    fish = homeModule;
    fish-darwin = homeDarwinModule;
    fish-linux = homeLinuxModule;
  };
  flake.modules.nixos.fish = systemModule;
  flake.modules.darwin.fish = darwinSystemModule;

  perSystem =
    { pkgs, ... }:
    {
      checks.fish-project-root =
        pkgs.runCommand "fish-project-root"
          {
            nativeBuildInputs = [
              pkgs.fish
              pkgs.jujutsu
              pkgs.git
              pkgs.python3
            ];
          }
          ''
            python3 ${./_fish/test_croot.py} ${./_fish/croot.fish} fish jj git
            touch "$out"
          '';
    };

  # The whole interactive environment in one output: fish's aliases,
  # abbreviations and startup reach for eza, zellij, tmux, television and the
  # editor, so the portable shell carries the features it names instead of
  # falling back to whatever the foreign host provides. The host-specific
  # `fish-linux` and `fish-darwin` leaves stay out -- their `rebuild`
  # abbreviation points at a checkout that only exists on nerv and asuka.
  seele.portable.fish = {
    modules = [
      "fish"
      "atuin"
      "bat"
      "bottom"
      "direnv"
      "eza"
      "fd"
      "fzf"
      "gh-dash"
      "git"
      "github-cli"
      "glow"
      "hunk"
      "jq"
      "jujutsu"
      "lazygit"
      "nixvim"
      "ripgrep"
      "sesh"
      "starship"
      "television"
      "tmux"
      "yazi"
      "zellij"
      "zoxide"
    ];
  };
}
