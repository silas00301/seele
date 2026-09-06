{ lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        t3code-nightly =
          let
            version = "0.0.39-nightly.20260906.1316";
            src = pkgs.fetchurl {
              url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
              hash = "sha256-bja7Nh2gRVUFkKKSEGOEroS39H/+2ySr2e9Buasv4W4=";
            };
            contents = pkgs.appimageTools.extract {
              pname = "t3code";
              inherit version src;

              # The AppImage's own AppRun prepends its `usr/lib` to
              # LD_LIBRARY_PATH, and every process started from inside the
              # editor -- a terminal, an agent's shell -- inherits it. The
              # bundled libnotify predates
              # `notify_notification_get_activation_app_launch_context`, so it
              # shadowed the current one and any `notify-send` run from in
              # here died on the missing symbol. Dropping it leaves the
              # matching library below as the only one on that path.
              postExtract = ''
                rm -f "$out/usr/lib/libnotify.so"*
              '';
            };
          in
          # Wrapped from the extracted tree rather than the AppImage, because
          # `wrapType2` extracts it a second time internally and would restore
          # the library removed above.
          pkgs.appimageTools.wrapAppImage {
            pname = "t3code";
            inherit version contents;

            extraPkgs = pkgs: [ pkgs.libnotify ];

            extraInstallCommands = ''
              install -Dm444 ${contents}/t3code.desktop "$out/share/applications/t3code.desktop"
              substituteInPlace "$out/share/applications/t3code.desktop" \
                --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=t3code --no-sandbox %U'
              cp -r ${contents}/usr/share/icons "$out/share"
            '';

            meta = {
              description = "Nightly T3 Code desktop AppImage";
              homepage = "https://github.com/pingdotgg/t3code";
              license = lib.licenses.mit;
              mainProgram = "t3code";
              platforms = [ "x86_64-linux" ];
              sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            };
          };
      };
    };
}
