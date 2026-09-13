{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.node-core = import (inputs.seele-shell + "/projects/node/package.nix") { inherit pkgs; };
  };
}
