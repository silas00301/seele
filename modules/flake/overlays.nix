{ inputs, ... }:
{
  flake.overlays = {
    librepods = final: prev: {
      librepods = prev.librepods.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../packages/_seele-shell/librepods-status.patch ];
      });
    };

    noctalia = final: prev: {
      noctalia = inputs.noctalia.packages.${prev.stdenv.hostPlatform.system}.default;
    };

    zjstatus = final: prev: {
      zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    };
  };
}
