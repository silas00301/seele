{ ... }:
let
  module =
    { config, pkgs, ... }:
    let
      rebootWindowsService = pkgs.writeShellScript "reboot-windows" ''
        set -o errexit -o nounset -o pipefail

        boot_number="$(
          LC_ALL=C ${pkgs.efibootmgr}/bin/efibootmgr |
            ${pkgs.gawk}/bin/awk '
              match($0, /^Boot([[:xdigit:]]{4})\*?[[:space:]]+Windows Boot Manager([[:space:]]|$)/, fields) {
                print fields[1]
                exit
              }
            '
        )"

        if [[ -z "$boot_number" ]]; then
          echo "Windows Boot Manager EFI entry not found" >&2
          exit 1
        fi

        ${pkgs.efibootmgr}/bin/efibootmgr --bootnext "$boot_number"
        exec ${pkgs.systemd}/bin/systemctl --no-block reboot
      '';

      rebootWindows = pkgs.writeShellScriptBin "reboot-windows" ''
        exec ${pkgs.systemd}/bin/systemctl --no-block start reboot-windows.service
      '';
    in
    {
      boot.loader = {
        efi.canTouchEfiVariables = true;
        limine = {
          enable = true;
          efiSupport = true;
          extraEntries = ''
            /Windows
              protocol: efi_boot_entry
              entry: Windows Boot Manager
          '';
          maxGenerations = 2;
          secureBoot = {
            enable = true;
            autoGenerateKeys = true;
          };
        };
      };

      environment.systemPackages = [ rebootWindows ];

      security.polkit = {
        enable = true;
        extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                action.lookup("unit") == "reboot-windows.service" &&
                action.lookup("verb") == "start" &&
                subject.user == "${config.username}") {
              return polkit.Result.YES;
            }
          });
        '';
      };

      systemd.services.reboot-windows = {
        description = "Reboot directly into Windows";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = rebootWindowsService;
        };
      };
    };
in
{
  flake.modules.nixos.nerv-limine = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
