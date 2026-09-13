{ ... }:
{
  perSystem = { config, ... }: {
    apps.inputs = {
      type = "app";
      program = "${config.packages.config-tools}/bin/seele-inputs";
      meta.description = "Inspect local flake input pins and follows without fetching";
    };
    checks.inputs-report = config.packages.config-tools;
  };
}
