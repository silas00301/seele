{ ... }:
let
  module = {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "silash" ];
    };

    environment.etc."1password/custom_allowed_browsers" = {
      text = ''
        .zen-beta-wrapped
        zen-bin
        zen
        zen-beta
      '';
      mode = "0755";
    };
  };
in
{
  flake.modules.nixos.pm-1password = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
