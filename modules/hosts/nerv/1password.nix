{ ... }:
let
  module =
    { config, ... }:
    {
      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ config.username ];
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
  flake.modules.nixos.nerv-1password = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
