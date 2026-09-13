{ ... }:
{
  perSystem = { config, ... }: {
    apps.check = {
      type = "app";
      # This native helper uses the caller's Nix distribution and never installs one.
      program = "${config.packages.repo-tools}/bin/seele-check";
      meta.description = "Format and validate Seele, optionally building the native host";
    };
    checks.check-command = config.packages.repo-tools;
  };
}
