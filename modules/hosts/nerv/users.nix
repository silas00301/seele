{ ... }:
let
  module =
    { config, pkgs, ... }:
    {
      users.users.${config.username} = {
        isNormalUser = true;
        description = "Silas";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        packages = with pkgs; [
          firefox
          gparted
          lxqt.pavucontrol-qt
        ];
      };

      fonts = {
        packages = with pkgs; [
          nerd-fonts.geist-mono
          maple-mono.NF-CN
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          noto-fonts-color-emoji
          noto-fonts-monochrome-emoji
          noto-fonts-emoji-blob-bin
        ];
        fontconfig.defaultFonts = {
          serif = [
            "Noto Serif"
            "Noto Serif CJK JP"
          ];
          sansSerif = [
            "Noto Sans"
            "Noto Sans CJK JP"
          ];
          monospace = [
            "Maple Mono NF CN"
            "Noto Sans Mono"
          ];
        };
      };
    };
in
{
  flake.modules.nixos.nerv-users = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
