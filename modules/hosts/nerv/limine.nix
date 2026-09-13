{ inputs, ... }:
let
  module =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      desktopTools = inputs.seele-shell.lib.mkNativePackage {
        inherit pkgs;
        name = "desktop-tools";
      };
      windowsTools =
        pkgs.runCommand "seele-windows-boot"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
          }
          ''
            mkdir -p "$out/bin"
            makeBinaryWrapper ${desktopTools}/bin/reboot-windows "$out/bin/reboot-windows" \
              --set SEELE_SYSTEMCTL ${lib.getExe' pkgs.systemd "systemctl"}
            makeBinaryWrapper ${desktopTools}/bin/reboot-windows-service "$out/bin/reboot-windows-service" \
              --set SEELE_SYSTEMCTL ${lib.getExe' pkgs.systemd "systemctl"} \
              --set SEELE_EFIBOOTMGR ${lib.getExe pkgs.efibootmgr}
          '';
      rebootWindowsService = "${windowsTools}/bin/reboot-windows-service";
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

      environment.systemPackages = [ windowsTools ];

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
          TimeoutStartSec = 30;
        };
      };
    };
in
{
  flake.modules.nixos.nerv-limine = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
