{ ... }:
let
  # `nix develop` and `nix-shell` start bash with an rcfile that sources
  # ~/.bashrc before it applies the environment, and the bash feature hands
  # every interactive bash to fish. Without this wrapper the fish that opens
  # therefore lacks the shell's packages and variables, which only appear in the
  # bash left behind once fish exits. nix-your-shell rewrites `nix develop`,
  # `nix shell` and `nix-shell` to run fish as their command instead, after the
  # environment is in place; `nix build` and every other subcommand pass
  # through unchanged, and `nh` calls the real binary.
  module = {
    programs.nix-your-shell = {
      enable = true;
      # zsh only bridges to fish, so a wrapper there would never be reached.
      enableZshIntegration = false;
    };
  };
in
{
  flake.modules.homeManager."nix-your-shell" = module;
}
