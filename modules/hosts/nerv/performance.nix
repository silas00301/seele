{ ... }:
let
  module = {
    # Ryzen 5 3600 currently exposes acpi-cpufreq, not amd-pstate. PPD only
    # offers its placeholder driver here; let cpufreq own the policy instead.
    powerManagement.cpuFreqGovernor = "performance";
    services.power-profiles-daemon.enable = false;

    # This machine has 12 logical CPUs and 32 GiB RAM. Avoid 12 simultaneous
    # builds each asking for all 12 CPUs. Builders may ignore the cores hint.
    nix.settings = {
      max-jobs = 2;
      cores = 6;
    };

    # Give memory-heavy builds a compressed fallback instead of immediately
    # running out of RAM. The 50% is logical capacity, not reserved memory.
    zramSwap = {
      enable = true;
      algorithm = "lz4";
      memoryPercent = 50;
    };

    boot.kernel.sysctl = {
      # Balance anonymous pages against file cache with RAM-backed swap.
      "vm.swappiness" = 100;
      # Zram has no seek latency; don't decompress speculative swap-in pages.
      "vm.page-cluster" = 0;
    };
  };
in
{
  flake.modules.nixos.nerv-performance = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
