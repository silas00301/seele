{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        seele-polkit =
          let
            quickshell = inputs.quickshell.packages.${system}.default;
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "seele-polkit";
            version = "1.0.0";

            dontUnpack = true;
            dontWrapQtApps = true;
            nativeBuildInputs = [
              pkgs.makeWrapper
              pkgs.nodejs
              pkgs.qt6.qtdeclarative
            ];

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/bin" "$out/share/seele-polkit"
              install -m644 ${./_seele-polkit/shell.qml} "$out/share/seele-polkit/shell.qml"

              # Same seeded generator seele-shell uses, so the grain film is the
              # identical texture rather than a second one that almost matches.
              node ${./_seele-shell/grain.js} "$out/share/seele-polkit/grain.png"
              makeWrapper ${quickshell}/bin/quickshell "$out/bin/seele-polkit" \
                --add-flags "-p $out/share/seele-polkit"

              runHook postInstall
            '';

            doInstallCheck = true;
            installCheckPhase = ''
              runHook preInstallCheck

              test -f "$out/share/seele-polkit/shell.qml"
              test -s "$out/share/seele-polkit/grain.png"
              test -x "$out/bin/seele-polkit"
              ${quickshell}/bin/quickshell --private-check-compat
              qmllint -I ${quickshell}/lib/qt-6/qml "$out/share/seele-polkit/shell.qml"

              runHook postInstallCheck
            '';

            meta = {
              description = "Seele-native Quickshell PolicyKit authentication agent";
              license = lib.licenses.mit;
              platforms = lib.platforms.linux;
              mainProgram = "seele-polkit";
            };
          };
      };
    };
}
