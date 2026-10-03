{ ... }:
let
  module = {
    programs.tealdeer = {
      enable = true;
      # The first `tldr` fetches the missing cache itself; after that Home
      # Manager's weekly `tldr-update` timer keeps it fresh and a lookup reads
      # local pages. tealdeer 1.9 refuses a lookup whose in-command refresh
      # fails rather than showing the stale pages, so that refresh is only a
      # backstop for a timer that has not succeeded in 90 days.
      settings.updates = {
        auto_update = true;
        auto_update_interval_hours = 24 * 90;
      };
    };

    # A weekly refresh that finds the machine offline retries instead of
    # leaving a failed user unit for System Health to report.
    systemd.user.services.tldr-update.Service = {
      Restart = "on-failure";
      RestartSec = "15min";
    };
  };
in
{
  flake.modules.homeManager."tealdeer" = module;
}
