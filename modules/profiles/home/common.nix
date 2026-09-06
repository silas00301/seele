{ config, ... }:
let
  modules = config.flake.modules.homeManager;
  base = { pkgs, ... }: {
    home.stateVersion = "24.05";

    home.packages = [
      pkgs.nerd-fonts.geist-mono
      pkgs.maple-mono.NF-CN
      pkgs.vue-language-server
      pkgs.glow
      pkgs.obsidian
      pkgs.nixd
    ];

    home.sessionVariables = { };

    # Home Manager's generated option manpage currently loses the context on
    # Nixpkgs declaration paths, which makes Nix warn that its options.json
    # derivation is unreliable.
    manual.manpages.enable = false;
  };
  profile = {
    imports = [
      modules.catppuccin
      modules.stylix
      modules.atuin
      modules.bash
      modules.bat
      modules.bottom
      modules.brave
      modules.determinate
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
