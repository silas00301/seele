{ ... }:
let
  homeModule = {
    programs.fish = {
      enable = true;
      functions = {
        gitignore = "curl -sL https://ww.gitignore.io/api/$argv";
        mkcd = "mkdir -p $argv && cd $argv";
        last_history_item = "echo $history[1]";
        edit = "$EDITOR $argv";
      };
      shellAliases = {
        ls = "eza -la --git";
        l1 = "eza -1 --icons=never";
        zf = "zellij run -f --";
        jjn = "jj --no-pager";
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
          expansion = "nh darwin switch -H wm";
        };
      };
    };
  homeLinuxModule = {
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
}
