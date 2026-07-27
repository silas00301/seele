{ pkgs, ... }:

{
  home.stateVersion = "24.05";

  home.packages = [
    pkgs.nerd-fonts.geist-mono
    pkgs.maple-mono.NF-CN
    pkgs.bat
    pkgs.vue-language-server
    pkgs.glow
    pkgs.obsidian
    pkgs.insomnia
    pkgs.nixd
    pkgs.nil
  ];

  imports = [
    ./themes/catppuccin.nix

    ./programs/atuin.nix
    ./programs/bash.nix
    ./programs/bat.nix
    ./programs/bottom.nix
    ./programs/brave.nix
    ./programs/direnv.nix
    ./programs/eza.nix
    ./programs/fd.nix
    ./programs/fish.nix
    ./programs/fzf.nix
    ./programs/git.nix
    ./programs/github-cli.nix
    ./programs/hunk.nix
    ./programs/jq.nix
    ./programs/jujutsu.nix
    ./programs/nh.nix
    ./programs/nixvim.nix
    ./programs/ripgrep.nix
    ./programs/sesh.nix
    ./programs/starship.nix
    ./programs/television.nix
    ./programs/tmux.nix
    ./programs/yazi.nix
    ./programs/zoxide.nix
    ./programs/zen-browser.nix
    ./programs/zsh.nix
  ];

  home.sessionVariables = { };

  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  programs.home-manager.enable = true;
}
