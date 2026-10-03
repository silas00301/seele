{ lib }:
let
  destination = "\${SEELE_PORTABLE_HOME:-\${XDG_CACHE_HOME:-$HOME/.cache}/seele/portable}/rg";
  relocate = import ./config-environment.nix {
    inherit lib;
    configHome = "/var/empty/seele-portable/.config";
    configDirectory = destination;
  };
in
lib.runTests {
  testRipgrep = {
    expr = relocate "/var/empty/seele-portable/.config/ripgrep/ripgreprc";
    expected = "${destination}/ripgrep/ripgreprc";
  };
  testStarship = {
    expr = relocate "/var/empty/seele-portable/.config/starship.toml";
    expected = "${destination}/starship.toml";
  };
  testConfigRoot = {
    expr = relocate "/var/empty/seele-portable/.config";
    expected = destination;
  };
  testSimilarPrefix = {
    expr = relocate "/var/empty/seele-portable/.config-backup/settings";
    expected = "/var/empty/seele-portable/.config-backup/settings";
  };
  testEmbeddedPath = {
    expr = relocate "--config=/var/empty/seele-portable/.config/settings";
    expected = "--config=/var/empty/seele-portable/.config/settings";
  };
  testStatePath = {
    expr = relocate "/var/empty/seele-portable/.local/state/history";
    expected = "/var/empty/seele-portable/.local/state/history";
  };
  testStorePath = {
    expr = relocate "/nix/store/example/config";
    expected = "/nix/store/example/config";
  };
  testRuntimeTemplate = {
    expr = relocate "\${XDG_DATA_HOME:-$HOME/.local/share}/application";
    expected = "\${XDG_DATA_HOME:-$HOME/.local/share}/application";
  };
  testScalar = {
    expr = relocate 123;
    expected = "123";
  };
}
