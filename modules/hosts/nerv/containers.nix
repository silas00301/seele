{ config, ... }:
let
  # Only `nerv` gets a container runtime. `asuka` is aarch64-darwin, where
  # podman runs Linux containers inside a `podman machine` VM it has to
  # provision, start and keep in sync with the host; that is a different
  # feature with its own lifecycle and disk budget, not this module with
  # another platform in its import list.
  module = {
    imports = [ config.flake.modules.nixos.podman ];
  };
in
{
  flake.modules.nixos.nerv-containers = module;
  flake.modules.nixos.nerv = module;
}
