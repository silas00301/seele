{ ... }:
let
  homeModule = {
    programs.zsh = {
      enable = true;
      initContent = ''
        fish
      '';
    };
  };
  systemModule =
    { config, pkgs, ... }:
    {
      users.users.${config.username}.shell = pkgs.zsh;
    };
in
{
  flake.modules.homeManager.zsh = homeModule;
  flake.modules.nixos.zsh = systemModule;
  flake.modules.darwin.zsh = systemModule;
}
