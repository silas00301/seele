let
  quad9 = import ./_dns/quad9.nix;
  # The allowlist the Control Center can compare and put back. A later quiet
  # morning audit is deliberately not part of this slice: nothing here watches
  # or notifies. The file is root-owned declarative config, read by seele-drift,
  # and it is not a second store of live state.
  catalog = {
    version = 1;
    checks = {
      quad9-dot.dns = quad9.dns;
      podman-rootless = { };
      remote-shell = { };
    };
  };
  module = {
    environment.etc."seele/drift.json".text = builtins.toJSON catalog;
  };
in
{
  flake.modules.nixos.nerv-drift = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
