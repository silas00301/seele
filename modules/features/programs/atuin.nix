{ ... }:
let
  module =
    { config, lib, ... }:
    {
      programs.atuin = {
        enable = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
        settings = {
          search_mode = "fuzzy";
          filter_mode = "global";
          filter_mode_shell_up_key_binding = "directory";
          search_mode_shell_up_key_binding = "prefix";
          enter_accept = false;
        };
      };

      programs.fish =
        lib.mkIf (config.programs.atuin.enable && config.programs.atuin.enableFishIntegration)
          {
            # Define Fish's standard hook directly. Fish reapplies it when
            # switching between vi and Emacs keys. This also avoids Home
            # Manager's binds command type, which is incompatible with the
            # nixpkgs v2 module merge mechanism until home-manager#9939 lands.
            functions.fish_user_key_bindings = ''
              bind --mode default ctrl-r _atuin_search
              bind --mode insert ctrl-r _atuin_search
            '';

            # Television's packaged integration also binds Ctrl-R. Apply the
            # declared owner after all integrations have loaded.
            # Television keeps Ctrl-T; Atuin's native Up handler stays in place.
            shellInitLast = lib.mkAfter ''
              if status is-interactive
                fish_user_key_bindings
              end
            '';
          };
    };
in
{
  flake.modules.homeManager."atuin" = module;

  seele.portable.atuin = { };
}
