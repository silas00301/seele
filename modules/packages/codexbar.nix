{ lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        codexbar = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "codexbar-cli";
          version = "0.56.7";

          src = pkgs.fetchurl {
            url = "https://github.com/steipete/CodexBar/releases/download/v${finalAttrs.version}/CodexBarCLI-v${finalAttrs.version}-linux-x86_64.tar.gz";
            hash = "sha256-XDsk4o7jaJ/+esc3c6xkxX6rYB4K2RIm0S272xzChv8=";
          };

          sourceRoot = ".";

          nativeBuildInputs = [
            pkgs.autoPatchelfHook
            pkgs.makeWrapper
          ];

          buildInputs = [
            pkgs.curl
            pkgs.sqlite
            pkgs.stdenv.cc.cc.lib
          ];

          installPhase = ''
            runHook preInstall

            mkdir -p "$out/libexec/codexbar" "$out/bin"
            install -m755 CodexBarCLI "$out/libexec/codexbar/CodexBarCLI"
            install -m644 VERSION "$out/libexec/codexbar/VERSION"
            cp -R CodexBar_CodexBarCore.bundle "$out/libexec/codexbar/"
            makeWrapper "$out/libexec/codexbar/CodexBarCLI" "$out/bin/codexbar"

            runHook postInstall
          '';

          doInstallCheck = true;
          installCheckPhase = ''
            runHook preInstallCheck

            test "$($out/bin/codexbar --version)" = "CodexBar ${finalAttrs.version}"

            runHook postInstallCheck
          '';

          meta = {
            description = "Show usage stats for AI coding-provider limits";
            homepage = "https://codexbar.app/";
            license = lib.licenses.mit;
            platforms = [ "x86_64-linux" ];
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "codexbar";
          };
        });
      };
    };
}
