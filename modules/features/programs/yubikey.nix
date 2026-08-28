{ ... }:
let
  # A FIDO credential is bound to the relying party it was enrolled under, and
  # pam_u2f derives that from `pam://$HOSTNAME` unless told otherwise. That
  # default makes enrolled keys hostage to the machine's name: renaming the host
  # orphans every credential, the authenticator answers FIDO_ERR_NO_CREDENTIALS,
  # and the module fails on every attempt. Under a `sufficient` control that
  # failure is silent, because the password fallback still succeeds, so it can
  # sit unnoticed until a stack turns `required`. This flake lost its keys that
  # way once already, when `nerv` was renamed from `pm`.
  #
  # Bind the identity to the flake instead of to a host. One enrollment then
  # covers every Seele host importing this module, and no future rename can
  # invalidate it. Treat the value as enrolled-key state rather than
  # configuration: changing it invalidates every key at once and, with `login`
  # at `required`, locks the account out of the machine. Re-enroll first, with a
  # matching `pamu2fcfg -o <relyingParty> -i <relyingParty>`.
  relyingParty = "pam://seele";

  module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # A second-factor surface takes the password first and the touch second.
      #
      # Seele Lock and `login` both collect the password before pam_u2f blocks
      # for a hardware-token touch. Keeping both entry surfaces on one order
      # also means a wrong password fails before asking for the token.
      #
      # NixOS orders u2f ahead of unix, which suits the `sufficient` approval
      # surfaces below but not these, so invert the pair. `requisite` on unix
      # short-circuits a wrong password before asking for a touch, and
      # `sufficient` on u2f lets its success end the stack ahead of the trailing
      # pam_deny. Both must still pass, so this stays 2FA -- the same guarantee
      # as u2f `required`, in the opposite order.
      #
      # The `order` is a relative offset because NixOS reserves the right to
      # renumber its built-in rules, and `unix` here names the verifying rule at
      # the end of the stack, not `login`'s early priming pass at `unix-early`.
      secondFactor = service: {
        u2f.enable = true;

        rules.auth = {
          unix.control = lib.mkForce "requisite";

          u2f = {
            control = lib.mkForce "sufficient";
            order = lib.mkForce (config.security.pam.services.${service}.rules.auth.unix.order + 10);
          };
        };
      };
    in
    {
      security.pam = {
        # `settings` has no per-service counterpart: pam.nix hands this one
        # attribute set to every service that enables the module below.
        u2f.settings = {
          origin = relyingParty;
          appid = relyingParty;

          # Without a cue pam_u2f blocks for the touch while printing nothing,
          # and the surface reads as hung.
          #
          # Seele Lock renders PAM_TEXT_INFO directly in its password field. A
          # clear cue still matters because its lock surface covers the desktop
          # shell and the touch detector behind it.
          cue = true;
          cue_prompt = "Place your finger on the YubiKey";
        };

        services = {
          # Session entry takes password *and* touch. greetd's own service is
          # `auth substack login`, so the greeter inherits this without an entry
          # of its own, and Seele Greeter renders the cue in place of the password
          # box because greetd's IPC carries PAM_TEXT_INFO as an `info` message.
          login = secondFactor "login";

          # Quickshell's PAM bridge names this service explicitly. The system
          # module owns it because Home Manager cannot create PAM services.
          "seele-lock" = secondFactor "seele-lock";

          # Approval surfaces: touch instead of typing the password. These keep
          # NixOS' u2f-first order, because a `sufficient` module placed after
          # `unix` would never be reached.
          sudo.u2f = {
            enable = true;
            control = "sufficient";
          };

          # sudo-rs declares this alongside `sudo`, and it is the same approval
          # surface, so it takes the same treatment rather than quietly falling
          # back to the password.
          sudo-i.u2f = {
            enable = true;
            control = "sufficient";
          };

          "polkit-1".u2f = {
            enable = true;
            control = "sufficient";
          };
        };
      };

      # polkit 127 does not run its PAM conversation in the agent. It hands the
      # request to a socket-activated helper that upstream hardens with
      # `PrivateDevices=yes` and `ProtectHome=yes`, which leaves pam_u2f there
      # able to reach neither `/dev/hidraw*` nor the authfile under `~/.config`.
      # It fails before touching the key, so the approval surface silently falls
      # back to the password however the agent is written.
      #
      # nixpkgs relaxes exactly this, but only under the global
      # `security.pam.u2f.enable`, which stays off below. Carry the same
      # relaxation directly; the values mirror the ones nixpkgs would apply.
      systemd.services."polkit-agent-helper@".serviceConfig = {
        PrivateDevices = false;
        DeviceAllow = [
          "/dev/urandom r"
          "char-hidraw rw"
        ];
        ProtectHome = "read-only";
      };

      # pamu2fcfg writes the `~/.config/Yubico/u2f_keys` mappings every stack
      # above depends on. The global `security.pam.u2f.enable` that would
      # otherwise ship it stays off, because it would also attach the module to
      # sshd, su, and every other service.
      environment.systemPackages = [ pkgs.pam_u2f ];

      programs.yubikey-touch-detector = {
        enable = true;
        libnotify = false;
        unixSocket = true;
      };
    };
in
{
  flake.modules.nixos.yubikey = module;
}
