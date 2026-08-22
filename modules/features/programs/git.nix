{ ... }:
let
  module = ({
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "Silas";
          email = "contact@silash.dev";
        };
        gpg = {
          format = "ssh";
        };
        push = {
          autoSetupRemote = true;
          followTags = true;
          default = "simple";
        };
        fetch = {
          prune = true;
          pruneTags = true;
          all = true;
        };
        diff = {
          algorithm = "histogram";
          colorMoved = "plain";
          renames = true;
          mnemonicPrefix = true;
        };
        rerere = {
          enabled = true;
          autoupdate = true;
        };
        rebase = {
          autoSquash = true;
          autoStash = true;
          updateRefs = true;
        };
        url = {
          "git@github.com".insteadOf = "gh";
          "git@github.com:silas00301".insteadOf = "me";
        };
        pull.rebase = true;
        merge.conflictStyle = "zdiff3";
        branch.sort = "-committerdate";
        column.ui = "auto";
        help.autocorrect = "prompt";
        init.defaultBranch = "main";
        aliases = {
          co = "checkout";
        };
      };
      includes = [
        {
          condition = "gitdir:~/Developer/work/";
          path = "~/Developer/work/.gitconfig";
        }
      ];
      signing = {
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPViOU8+CC3RPIs8PAZyHaJYr+oXXNBPw2kAT/zeE9SJ";
        signByDefault = true;
        format = "ssh";
      };
    };
  });
in
{
  flake.modules.homeManager."git" = module;
}
