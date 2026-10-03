{ lib, ... }:
{
  perSystem =
    { pkgs, system, self', ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        hermes-desktop =
          let
            # Official Desktop Light: remote UI only, without a Python agent.
            # A fixed-output tarball also lets upstream's importNpmLock read
            # the exact lockfile at evaluation; no mutable dependency hash.
            source = builtins.fetchTarball {
              url = "https://codeload.github.com/NousResearch/hermes-agent/tar.gz/10c6188de188871f64a88dd95bc6b262adb0c307";
              sha256 = "sha256-+ed0+D7YxrbQmY4GFsxlea/F5vwwalDR2HNytXphcGQ=";
            };
            npmLib = pkgs.callPackage (source + "/nix/lib.nix") {
              npm-lockfile-fix = null;
              nodejs_26 = pkgs.nodejs;
              callPackage = pkgs.newScope { nodejs_26 = pkgs.nodejs; };
            };
            hermesNpmLib = npmLib // {
              buildNpmPackage = attrs: npmLib.buildNpmPackage (attrs // {
                version = "2026.9.24";
                nativeBuildInputs = (attrs.nativeBuildInputs or [ ]) ++ [ pkgs.python3 ];
                postCheck = (attrs.postCheck or "") + ''
                  node ${./_hermes/bridge.test.cjs} "$PWD"
                '';
                postPatch = (attrs.postPatch or "") + ''
                  python3 ${./_hermes/patch.py} "$PWD" ${./_hermes} \
                    ${self'.packages.seele-shell}/share/seele-shell/shared/Theme.qml
                  substituteInPlace apps/desktop/electron/seele-lifecycle.ts \
                    --replace-fail '@hermesPublisher@' '${self'.packages.seele-shell}/bin/seele-hermes'
                '';
              });
            };
            generatedIcons = pkgs.runCommand "hermes-desktop-icons" {
              nativeBuildInputs = [ pkgs.librsvg ];
            } ''
              mkdir -p "$out/apps/desktop/public" "$out/apps/desktop/assets"
              rsvg-convert -w 1024 -h 1024 ${source}/assets/icon-master.svg \
                -o "$out/apps/desktop/public/apple-touch-icon.png"
              cp "$out/apps/desktop/public/apple-touch-icon.png" "$out/apps/desktop/assets/icon.png"
              rsvg-convert -w 256 -h 256 ${source}/assets/nous-girl-black.svg \
                -o "$out/apps/desktop/public/nous-girl.png"
              rsvg-convert -w 256 -h 256 ${source}/assets/nous-girl-white.svg \
                -o "$out/apps/desktop/public/nous-girl-dark.png"
            '';
            installStampFile = pkgs.writeText "hermes-desktop-light-install-stamp.json" (builtins.toJSON {
              schemaVersion = 2;
              commit = "10c6188de188871f64a88dd95bc6b262adb0c307";
              commitDate = null;
              branch = null;
              builtAt = null;
              dirty = false;
              source = "nix";
              distribution = "nix";
              updateMechanism = "external";
              baseVersion = "2026.9.24";
              displayVersion = "2026.9.24-seele";
              distance = null;
              payload = "light";
              tag = null;
            });
          in
          pkgs.callPackage (source + "/nix/desktop.nix") {
            inherit hermesNpmLib generatedIcons installStampFile;
            # Upstream's wrapper requires a deployment executable even for
            # Light. Its immutable Light stamp prevents local bootstrap; the
            # defensive stub cannot accidentally create a local agent.
            hermesAgent = pkgs.writeShellScriptBin "hermes" ''
              echo "Use Hermes Desktop's remote connection settings." >&2
              exit 1
            '';
            extraEnv = {
              HERMES_DESKTOP_PASSWORD_STORE = "gnome-libsecret";
            };
          };
      };
    };
}
