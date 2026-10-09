{ lib }:
let
  feature = (import ../backups.nix { }).flake.modules.nixos.backups;
  package = name: { outPath = "/nix/store/fixture-${name}"; meta.mainProgram = name; };
  pkgs = {
    restic = package "restic";
    dbus = package "dbus";
    coreutils = package "coreutils";
    openssh = package "openssh";
    writeText = name: _: "/nix/store/fixture-${name}";
    writeShellScript = name: _: "/nix/store/fixture-${name}";
  };
  evaluate = settings: (lib.evalModules {
    specialArgs = {
      inherit pkgs;
      username = "fixture";
      selfPackages.maintenance = package "maintenance";
    };
    modules = [
      feature
      {
        options = {
          assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = [ ]; };
          services = lib.mkOption { type = lib.types.attrs; default = { }; };
          systemd = lib.mkOption { type = lib.types.attrs; default = { }; };
          home-manager = lib.mkOption { type = lib.types.attrs; default = { }; };
          networking.hostName = lib.mkOption { type = lib.types.str; default = "fixture"; };
        };
        config.seele.backup = settings;
      }
    ];
  }).config;
  disabled = evaluate { };
  active = evaluate {
    enable = true;
    repositoryFile = "/var/lib/fixture/repository";
    passwordFile = "/var/lib/fixture/password";
    paths = [ "/home/fixture" ];
    restoreSamples = [ "/home/fixture/Documents/example.txt" ];
  };
  sampleSettings = {
    enable = true; repositoryFile = "/var/lib/fixture/repository"; passwordFile = "/var/lib/fixture/password";
    paths = [ "/home/fixture" ]; restoreSamples = [ "/home/fixture/Documents/example.txt" ];
  };
  excluded = evaluate (sampleSettings // { exclude = [ "/home/fixture/Documents/" ]; });
  glob = evaluate (sampleSettings // { exclude = [ "/home/*/.cache" ]; });
  separate = evaluate (sampleSettings // { exclude = [ "/home/fixture/.cache" ]; });
  invalid = evaluate {
    enable = true;
    repositoryFile = "/nix/store/not-a-secret";
    passwordFile = "/var/lib/fixture/password";
    paths = [ "/home/fixture" ];
    restoreSamples = [ "/outside/example.txt" ];
  };
in
assert !(builtins.all (entry: entry.assertion) excluded.assertions);
assert !(builtins.all (entry: entry.assertion) glob.assertions);
assert builtins.all (entry: entry.assertion) separate.assertions;
assert disabled.systemd == { };
assert disabled.services == { };
assert builtins.all (entry: entry.assertion) active.assertions;
assert !(builtins.all (entry: entry.assertion) invalid.assertions);
assert active.services.restic.backups.seele.initialize == false;
assert active.services.restic.backups.seele.pruneOpts == [ ];
assert active.systemd.timers.seele-backup-restore.timerConfig.OnCalendar == "monthly";
assert active.systemd.timers.seele-backup-restore.timerConfig.Persistent;
assert active.systemd.services.restic-backups-seele.serviceConfig.ExecStartPost != "";
assert active.systemd.services.seele-backup-restore.serviceConfig.ProtectSystem == "strict";
assert builtins.length active.home-manager.users.fixture.seele.maintenance.backups.items == 2;
{ disabledByDefault = true; monthlyRestore = true; durableAgeMarkers = true; runtimeReferences = true; }
