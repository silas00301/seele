{ config, ... }:
let
  modules = config.flake.modules.homeManager;
  base = { pkgs, ... }: {
    home.stateVersion = "24.05";

    home.packages = [
      pkgs.nerd-fonts.geist-mono
      pkgs.maple-mono.NF-CN
      pkgs.bat
      pkgs.vue-language-server
      pkgs.glow
      pkgs.obsidian
      pkgs.nixd
      pkgs.nil
    ];

    home.sessionVariables = { };

    nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];
  };
  profile = {
    imports = [
      modules.catppuccin
      modules.atuin
      modules.bash
      modules.bat
      modules.bottom
      modules.brave
      modules.direnv
      modules.eza
      modules.fd
      modules.fish
      modules.fzf
      modules.git
      modules.github-cli
      modules.home-manager
      modules.hunk
      modules.jq
      modules.jujutsu
      modules.nh
      modules.nixvim
      modules.ripgrep
      modules.sesh
      modules.starship
      modules.television
      modules.tmux
      modules.yazi
      modules.zoxide
      modules.zen-browser
      modules.zsh
      base
    ];
  };
in
{
  flake.modules.homeManager = {
    home-base = base;
    common = profile;
  };
}
