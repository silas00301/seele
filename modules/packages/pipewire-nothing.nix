{ lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      backend = pkgs.pipewire.overrideAttrs (old: {
        pname = "pipewire-nothing";
        patches = (old.patches or [ ]) ++ [ ./_pipewire-nothing/volume-step.patch ];
        postPatch = (old.postPatch or "") + ''
          cp ${./_pipewire-nothing/volume-step.h} spa/plugins/bluez5/volume-step.h
          $CC -Wall -Wextra -Werror -I${./_pipewire-nothing} \
            ${./_pipewire-nothing/test-volume-step.c} -o /tmp/test-volume-step
          /tmp/test-volume-step
        '';
      });
    in
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        pipewire-nothing = pkgs.runCommand "pipewire-nothing-bluetooth" { } ''
          mkdir -p "$out/lib/spa-0.2/bluez5"
          ln -s ${backend}/lib/spa-0.2/bluez5/libspa-bluez5.so "$out/lib/spa-0.2/bluez5/"
        '';
      };
    };
}
