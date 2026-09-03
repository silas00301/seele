{ ... }:
{
  flake.modules.homeManager.proton-vpn =
    { pkgs, ... }:
    let
      python = pkgs.python3.override {
        packageOverrides = _final: previous: {
          proton-core = previous.proton-core.overridePythonAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./_proton-vpn/bcrypt-5.patch ];
            postCheck = (old.postCheck or "") + ''
              python ${./_proton-vpn/test-long-password.py}
            '';
          });
        };
      };
      proton-vpn = pkgs.proton-vpn.override {
        callPackage =
          package: arguments: pkgs.callPackage package (arguments // { python3Packages = python.pkgs; });
      };
    in
    {
      home.packages = [
        proton-vpn
        pkgs.proton-vpn-cli
      ];
    };
}
