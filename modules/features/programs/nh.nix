{ ... }:
let
  module = (
    { username, pkgs, ... }:
    {
      programs.nh = {
        enable = true;
        flake =
          if pkgs.stdenv.hostPlatform.isLinux then "/home/${username}/seele" else "/Users/${username}/seele";
        clean = {
          enable = true;
          extraArgs = "--keep 3 --keep-since 3d";
        };
      };

      # nh escalates on its own to activate a generation, and its `auto`
      # strategy tries doas, then sudo, before run0 -- so it lands on sudo and
      # prompts on the terminal. Naming run0 explicitly routes that escalation
      # through polkit instead, which is what puts it in the Seele Polkit dialog
      # with the key and the password both available.
      #
      # Left as a bare name rather than a store path on purpose: this picks the
      # running system's run0, and pinning one build of systemd for a privilege
      # escalation path would let it drift from the systemd actually booted.
      # run0 is systemd's, so Darwin keeps nh's own default.
      home.sessionVariables = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        NH_ELEVATION_STRATEGY = "run0";
      };
    }
  );
in
{
  flake.modules.homeManager."nh" = module;
}
