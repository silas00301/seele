{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      programs.gh = {
        enable = true;
        extensions = [
          pkgs.gh-skyline
        ];
        gitCredentialHelper = {
          enable = true;
          hosts = [
            "https://github.com"
            "https://gist.github.com"
          ];
        };
        settings = {
          git_protocol = "ssh";
          prompt = "enabled";
          aliases = {
            co = "pr checkout";
            web = "repo view --web";
          };
        };
      };

      programs._1password-shell-plugins.plugins = with pkgs; [
        gh
      ];
    }
  );
in
{
  flake.modules.homeManager."github-cli" = module;

  seele.portable.gh = {
    modules = [ "github-cli" ];
  };
}
