{ ... }:
let
  module = (
    # Edit this configuration file to define what should be installed on
    # your system.  Help is available in the configuration.nix(5) man page
    # and in the NixOS manual (accessible by running ‘nixos-help’).

    {
      config,
      pkgs,
      selfPackages,
      ...
    }:
    {
      imports = [
        # Include the results of the hardware scan.
      ];

      # Bootloader.
      boot.loader.efi.canTouchEfiVariables = true;

      boot.loader.grub = {
        enable = true;
        configurationLimit = 2;
        devices = [ "nodev" ];
        efiSupport = true;
        useOSProber = true;
      };

      system.activationScripts.cleanStaleGrubCopies.text = ''
        if [ -d /boot/kernels ]; then
          ${pkgs.findutils}/bin/find /boot/kernels -maxdepth 1 -type f -name '*.tmp' -delete
        fi
      '';

      boot.plymouth.enable = true;

      boot.lanzaboote = {
        enable = false;
        pkiBundle = "/var/lib/sbctl";
      };

      hardware = {
        graphics.enable = true;
        bluetooth.enable = true;
        nvidia = {
          modesetting.enable = true;
          open = true;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
        };
      };

      # systemd.user.services."spt-st" = {
      #   name = "spt-st";
      #   description = "spt-st auto fetch";
      #   startAt = "*-*-* *:*:0/30";

      #   serviceConfig = {
      #     Type = "oneshot";
      #   };

      #   path = with pkgs; [
      #     spotify-player
      #     jq
      #   ];

      #   script = ''
      #     mkdir -p /tmp/bar || true
      #     playing="$(${selfPackages.spt-st}/bin/spt-st)"
      #     if [[ "$playing" != "" ]]; then
      #       echo "$playing" > /tmp/bar/spt-status
      #     else
      #       rm /tmp/bar/spt-status || true
      #     fi
      #   '';
      # };

      services.xserver.videoDrivers = [ "nvidia" ];

      services.power-profiles-daemon.enable = true;

      services.upower.enable = true;

      networking.hostName = "pm"; # Define your hostname.
      # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

      # Configure network proxy if necessary
      # networking.proxy.default = "http://user:password@proxy:port/";
      # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

      # Enable networking
      networking.networkmanager.enable = true;

      # security.pam.services.hyprlock = { };

      security.pam.services = {
        login.u2fAuth = true;
        sudo.u2fAuth = true;
      };

      programs.kdeconnect.enable = true;

      programs.noctalia = {
        enable = true;
        recommendedServices.enable = true;
        systemd.enable = true;
      };

      # Set your time zone.
      time.timeZone = "Europe/Berlin";

      # Select internationalisation properties.
      i18n.defaultLocale = "en_US.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
      };

      # Enable the X11 windowing system.
      services.xserver.enable = true;

      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
      services.desktopManager.plasma6.enable = true;

      #Enable Hyprland
      programs.hyprland.enable = true;
      # Hint electron to use wayland
      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      programs.yubikey-touch-detector.enable = true;

      programs.zsh.enable = true;

      # Configure keymap in X11
      services.xserver.xkb = {
        layout = "de";
        variant = "";
      };

      # Configure console keymap
      console.keyMap = "de";

      # Enable CUPS to print documents.
      services.printing.enable = false;

      # Enable sound with pipewire.
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        # If you want to use JACK applications, uncomment this
        #jack.enable = true;

        # use the example session manager (no others are packaged yet so this is enabled by default,
        # no need to redefine it in your config for now)
        #media-session.enable = true;
      };

      # Enable touchpad support (enabled default in most desktopManager).
      # services.xserver.libinput.enable = true;

      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users.${config.username} = {
        isNormalUser = true;
        description = "Silas";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        packages = with pkgs; [
          firefox
          gparted
          lxqt.pavucontrol-qt
        ];
      };

      fonts = {
        packages = with pkgs; [
          nerd-fonts.geist-mono
          maple-mono.NF-CN
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          noto-fonts-color-emoji
          noto-fonts-monochrome-emoji
          noto-fonts-emoji-blob-bin
        ];
        fontconfig = {
          defaultFonts = {
            serif = [
              "Noto Serif"
              "Noto Serif CJK JP"
            ];
            sansSerif = [
              "Noto Sans"
              "Noto Sans CJK JP"
            ];
            monospace = [
              "Maple Mono NF CN"
              "Noto Sans Mono"
            ];
          };
        };
      };

      # Allow unfree packages
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment.systemPackages = with pkgs; [
        selfPackages.codexbar
        wget
        unzip
        sbctl
        wl-clipboard
      ];

      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ "silash" ];
      };

      environment.etc = {
        "1password/custom_allowed_browsers" = {
          text = ''
            .zen-beta-wrapped
            zen-bin
            zen
            zen-beta
          '';
          mode = "0755";
        };
      };

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      # Some programs need SUID wrappers, can be configured further or are
      # started in user sessions.
      # programs.mtr.enable = true;
      # programs.gnupg.agent = {
      #   enable = true;
      #   enableSSHSupport = true;
      # };

      # List services that you want to enable:

      # Enable the OpenSSH daemon.
      # services.openssh.enable = true;

      # Open ports in the firewall.
      # networking.firewall.allowedTCPPorts = [ ... ];
      # networking.firewall.allowedUDPPorts = [ ... ];
      # Or disable the firewall altogether.
      # networking.firewall.enable = false;

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It‘s perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      system.stateVersion = "23.11"; # Did you read the comment?

    }
  );
in
{
  flake.modules.nixos."pm-system" = module;
  flake.modules.nixos."pm" = module;
}
