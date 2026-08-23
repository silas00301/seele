{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        seele-shell =
          let
            quickshell = inputs.quickshell.packages.${system}.default;
            runtimePath = lib.makeBinPath [
              pkgs.bash
              pkgs.bluez
              pkgs.cameractrls-gtk4
              pkgs.coreutils
              pkgs.findutils
              pkgs.gawk
              pkgs.ghostty
              pkgs.hyprland
              pkgs.hyprlock
              pkgs.iproute2
              pkgs.jq
              pkgs.librepods
              pkgs.mako
              pkgs.networkmanager
              pkgs.networkmanagerapplet
              pkgs.pipewire
              pkgs.playerctl
              pkgs.socat
              pkgs.systemd
              pkgs.util-linux
              pkgs.uwsm
              pkgs.v4l-utils
              pkgs.vicinae
              pkgs.voxtype-vulkan
              pkgs.wireplumber
              pkgs.wl-clipboard
              quickshell
            ];
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "seele-shell";
            version = "1.0.0";

            dontUnpack = true;
            nativeBuildInputs = [
              pkgs.esbuild
              pkgs.jq
              pkgs.makeWrapper
              pkgs.nodejs
            ];

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/share/seele-shell" "$out/share/vicinae/extensions/seele-shell/assets" "$out/libexec/seele-shell" "$out/bin"
              install -m644 ${./_seele-shell/shell.qml} "$out/share/seele-shell/shell.qml"
              install -m644 ${./_seele-shell/CameraPreview.qml} "$out/share/seele-shell/CameraPreview.qml"
              install -m644 ${./_seele-shell/opencode-status.ts} "$out/share/seele-shell/opencode-status.ts"
              install -m644 ${./_seele-shell/pi-status.ts} "$out/share/seele-shell/pi-status.ts"

              cp ${./_seele-shell/vicinae/package.json} "$out/share/vicinae/extensions/seele-shell/package.json"
              cp ${./_seele-shell/vicinae/seele.svg} "$out/share/vicinae/extensions/seele-shell/assets/seele.svg"
              substitute ${./_seele-shell/vicinae/seele.tsx} seele.tsx \
                --replace-fail '@SEELE_SHELLCTL@' "$out/bin/seele-shellctl"
              substitute ${./_seele-shell/vicinae/keybindings.tsx} keybindings.tsx \
                --replace-fail '@HYPRCTL@' '${pkgs.hyprland}/bin/hyprctl'
              esbuild seele.tsx --bundle --platform=node --format=cjs --external:@raycast/api --external:react --external:react/jsx-runtime --outfile="$out/share/vicinae/extensions/seele-shell/seele.js"
              esbuild keybindings.tsx --bundle --platform=node --format=cjs --external:@raycast/api --external:react --external:react/jsx-runtime --outfile="$out/share/vicinae/extensions/seele-shell/keybindings.js"

              install -m755 ${./_seele-shell/agent-state.sh} "$out/libexec/seele-shell/agent-state"
              install -m755 ${./_seele-shell/agent-hook.sh} "$out/libexec/seele-shell/agent-hook"
              install -m755 ${./_seele-shell/agent-launch.sh} "$out/libexec/seele-shell/agent-launch"
              install -m755 ${./_seele-shell/agent-run.sh} "$out/libexec/seele-shell/agent-run"
              install -m755 ${./_seele-shell/control.sh} "$out/libexec/seele-shell/control"
              install -m755 ${./_seele-shell/ctl.sh} "$out/libexec/seele-shell/ctl"
              install -m755 ${./_seele-shell/yubikey-watch.sh} "$out/libexec/seele-shell/yubikey-watch"
              patchShebangs "$out/libexec/seele-shell"

              makeWrapper ${quickshell}/bin/quickshell "$out/bin/seele-shell" \
                --add-flags "-n -p $out/share/seele-shell" \
                --prefix QML2_IMPORT_PATH : "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml" \
                --prefix QT_PLUGIN_PATH : "${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins" \
                --prefix PATH : "$out/bin:${runtimePath}"
              makeWrapper "$out/libexec/seele-shell/agent-state" "$out/bin/seele-agent-state" \
                --prefix PATH : "$out/bin:${runtimePath}"
              makeWrapper "$out/libexec/seele-shell/agent-launch" "$out/bin/seele-agent" \
                --prefix PATH : "$out/bin:${runtimePath}"
              makeWrapper "$out/libexec/seele-shell/agent-run" "$out/bin/seele-agent-run" \
                --prefix PATH : "$out/bin:${runtimePath}"
              makeWrapper "$out/libexec/seele-shell/agent-hook" "$out/bin/seele-agent-hook" \
                --prefix PATH : "$out/bin:${runtimePath}"
              makeWrapper "$out/libexec/seele-shell/control" "$out/bin/seele-control" \
                --prefix PATH : "$out/bin:${runtimePath}"
              makeWrapper "$out/libexec/seele-shell/ctl" "$out/bin/seele-shellctl" \
                --set SEELE_SHELL_PATH "$out/share/seele-shell" \
                --prefix PATH : "$out/bin:${runtimePath}"
              makeWrapper "$out/libexec/seele-shell/yubikey-watch" "$out/bin/seele-yubikey-watch" \
                --prefix PATH : "$out/bin:${runtimePath}"

              runHook postInstall
            '';

            passthru.librepods = pkgs.librepods;

            doInstallCheck = true;
            installCheckPhase = ''
              runHook preInstallCheck

              test -f "$out/share/seele-shell/shell.qml"
              test -f "$out/share/seele-shell/CameraPreview.qml"
              test -f "$out/share/seele-shell/opencode-status.ts"
              test -f "$out/share/seele-shell/pi-status.ts"
              test -f "$out/share/vicinae/extensions/seele-shell/package.json"
              test -f "$out/share/vicinae/extensions/seele-shell/seele.js"
              test -f "$out/share/vicinae/extensions/seele-shell/keybindings.js"
              for command in seele-shell seele-agent-state seele-agent seele-agent-run seele-agent-hook seele-control seele-shellctl seele-yubikey-watch; do
                test -x "$out/bin/$command"
              done
              bash -n "$out/libexec/seele-shell/"*
              "$out/bin/seele-shellctl" --help >/dev/null
              bash ${./_seele-shell/tests/harness-status.sh} \
                "$out/share/seele-shell/pi-status.ts" \
                "$out/share/seele-shell/opencode-status.ts" \
                "$out/libexec/seele-shell/control" \
                "$out/libexec/seele-shell/agent-hook"

              runHook postInstallCheck
            '';

            meta = {
              description = "Seele-native Quickshell desktop shell";
              license = lib.licenses.mit;
              platforms = lib.platforms.linux;
              mainProgram = "seele-shell";
            };
          };
      };
    };
}
