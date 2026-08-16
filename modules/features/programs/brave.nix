{ ... }:
let
  module = (
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      catppuccin_themes = {
        mocha = "bkkmolkhemgaeaeggcmfbghljjjoofoh";
        macchiato = "cmpdlhmnmjhihmcfnigoememnffkimlk";
        frappe = "olhelnoplefjdmncknfphenjclimckaf";
        latte = "jhjnalhegpceacdhbplhnakmkdliaddd";
      };
    in
    {
      programs.chromium = {
        enable = true;
        package = pkgs.brave;
        extensions = [
          {
            id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; # uBlock Origin
          }
          {
            id = "clngdbkpkpeebahjckkjfobafhncgmne"; # Stylus
          }
          {
            id = "nngceckbapebfimnlniiiahkandclblb"; # Bitwarden
          }
          { id = lib.mkIf config.catppuccin.enable catppuccin_themes.${config.catppuccin.flavor}; }
        ];
        dictionaries = [
          pkgs.hunspellDictsChromium.en_US
          pkgs.hunspellDictsChromium.de_DE
        ];
      };
    }
  );
in
{
  flake.modules.homeManager."brave" = module;
}
