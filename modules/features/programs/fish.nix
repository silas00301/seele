{ ... }:
let
  homeModule =
    { config, lib, ... }:
    {
      programs.fish = {
        enable = true;
        functions = {
          gitignore = "curl -sL https://www.toptal.com/developers/gitignore/api/$argv";
          mkcd = "mkdir -p $argv && cd $argv";
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
