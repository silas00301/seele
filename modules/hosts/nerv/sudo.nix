{ ... }:
let
  module = {
    # sudo-rs keeps the `sudo` and `sudo-i` PAM service names, so the approval
    # stack the shared yubikey feature builds applies to it unchanged. Enabling
    # it also flips `security.sudo.enable` to false on its own; the two cannot
    # coexist, and the module asserts as much.
    security.sudo-rs.enable = true;
  };
in
{
  flake.modules.nixos.nerv-sudo = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
