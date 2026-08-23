{ ... }:
{
  flake.modules.homeManager.t3code = { selfPackages, ... }: {
    home.packages = [ selfPackages.t3code-nightly ];
  };
}
