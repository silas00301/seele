{ ... }:
let
  module = (
    {
      pkgs,
      lib,
      config,
      selfPackages,
      ...
    }:
    {
      programs.jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "Silas";
            email = "contact@silash.dev";
          };
          ui = {
            default-command = "log";
            pager = lib.mkIf config.programs.bat.enable "bat -p";
            diff-editor = [
              "nvim"
              "-c"
              "DiffEditor $left $right $output"
            ];
          };
          signing = {
            behavior = "own";
            backend = "ssh";
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPViOU8+CC3RPIs8PAZyHaJYr+oXXNBPw2kAT/zeE9SJ";
          };
          aliases = {
            tug = [
              "bookmark"
              "move"
              "--from"
              "heads(::@ & bookmarks())"
              "--to"
              "@"
            ];
            insert = [
              "new"
              "--insert-before"
              "@"
            ];
            reheat = [
              "rebase"
              "-d"
              "trunk()"
              "-s"
              "roots(trunk()..stack(@))"
            ];
            flip = [
              "util"
              "exec"
              "--"
              "jj-flip"
            ];
            "pr" = [
              "util"
              "exec"
              "--"
              "jj-pr"
            ];
          };
          revset-aliases = {
            "stack()" = "stack(@)";
            "stack(x)" = "stack(x, 2)";
            "stack(x, n)" = "ancestors(reachable(x, mutable()), n)";
          };
          git.private-commits = "description(glob:'private:*')";
        };
      };
      home.packages = [
        (pkgs.runCommand "seele-jj-helpers" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
          mkdir -p "$out/bin"
          for binary in jj-flip jj-pr; do
            makeWrapper "${selfPackages.repo-tools}/bin/$binary" "$out/bin/$binary" \
              --prefix PATH : ${
                lib.makeBinPath [
                  pkgs.jujutsu
                  pkgs.gh
                  pkgs.gum
                ]
              }
          done
        '')
      ];
    }
  );
in
{
  flake.modules.homeManager."jujutsu" = module;

  seele.portable.jj = {
    # Jujutsu's pager and diff formatter are chosen by whether bat and hunk are
    # present, and its `pr` alias shells out to gh, so all three take part in
    # the standalone evaluation the way they do on a host.
    modules = [
      "jujutsu"
      "bat"
      "hunk"
      "github-cli"
    ];
    binary = "jj";
  };
}
