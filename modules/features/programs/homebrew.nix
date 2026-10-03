{ ... }:
let
  analyticsEnvironment = { HOMEBREW_NO_ANALYTICS = "1"; };
  module = {
    homebrew = {
      enable = true;
      # Activation does not inherit the shell's environment.
      onActivation.extraEnv = analyticsEnvironment;
    };
    environment.variables = analyticsEnvironment;
  };
in
{
  flake.modules.darwin.homebrew = module;
}
