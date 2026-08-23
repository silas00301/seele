{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        t3code-nightly =
          let
            releases = builtins.fromJSON (builtins.readFile inputs."t3code-nightly-release");
            release = lib.findFirst (
              candidate: candidate.prerelease && lib.hasInfix "-nightly." candidate.tag_name
            ) (throw "GitHub returned no T3 Code nightly releases") releases;
            asset = lib.findFirst (
              candidate: lib.hasSuffix "-x86_64.AppImage" candidate.name
            ) (throw "The latest T3 Code nightly release has no x86_64 AppImage") release.assets;
            version = lib.removePrefix "v" release.tag_name;
            src = pkgs.fetchurl {
              url = asset.browser_download_url;
              hash = builtins.convertHash {
                hash = lib.removePrefix "sha256:" asset.digest;
                hashAlgo = "sha256";
                toHashFormat = "sri";
              };
            };
            contents = pkgs.appimageTools.extract {
              pname = "t3code";
              inherit version src;
            };
          in
          pkgs.appimageTools.wrapType2 {
            pname = "t3code";
            inherit version src;

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
