{ ... }:
let
  # Software that ships as a prebuilt Linux binary (an npm package's postinstall
  # download, a release tarball, a vendored language server) looks for
  # `/lib64/ld-linux-x86-64.so.2` and for its shared libraries below `/usr/lib`,
  # neither of which this system has. nix-ld answers both from the system
  # closure, so running one of those binaries needs neither patchelf nor an FHS
  # sandbox built around it. Packaging stays the better answer for anything
  # kept; this covers what is only run once.
  module = { pkgs, ... }: {
    programs.nix-ld.enable = true;

    # Upstream assigns its library set in the module's `config`, not as the
    # option's default, so these definitions merge with the systemd and Nix
    # libraries it already lists instead of replacing them. Keep the additions
    # to libraries a prebuilt command-line program loads on its own; graphical
    # toolkits stay out until a binary that needs them actually turns up.
    programs.nix-ld.libraries = with pkgs; [
      expat
      fontconfig
      freetype
      icu
      libffi
    ];

    # An AppImage is the other shape unpackaged software arrives in. The binfmt
    # registration makes an executable one run directly rather than only
    # through an explicit `appimage-run`, which is what a file manager or a
    # `./Foo.AppImage` in a shell ends up doing. An AppImage worth keeping is
    # still packaged instead, the way `t3code-nightly` is.
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
in
{
  flake.modules.nixos.foreign-binaries = module;
}
