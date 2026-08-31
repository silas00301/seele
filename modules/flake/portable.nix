{
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
let
  homeModules = config.flake.modules.homeManager;

  # The portable wrappers are evaluated once, away from any host, so they need a
  # user and a home directory that no generated file may depend on. Home Manager
  # only uses `home.homeDirectory` to derive the layout of `home-files`, which
  # the wrapper re-roots at runtime, so a sentinel keeps an accidental
  # dependency obvious in the built output instead of silently pointing a
  # foreign host at a directory it does not have.
  username = config.seele.hosts.nerv.username;
  homeDirectory = "/var/empty/seele-portable";

  # Home Manager assigns `home.file` targets relative to the home directory, so
  # a leaf that writes nothing below `.config` needs no runtime config tree and
  # must not have `XDG_CONFIG_HOME` redirected out from under it.
  writesConfig =
    hm: lib.any (file: lib.hasPrefix ".config/" file.target) (lib.attrValues hm.config.home.file);

  appModule =
    { name, ... }:
    {
      options = {
        modules = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ name ];
          example = [
            "jujutsu"
            "bat"
          ];
          description = ''
            Named `flake.modules.homeManager` features evaluated for this app.
            List every feature the app reads through, not just its own: the
            evaluation is standalone, so an unlisted feature resolves to its
            Home Manager default rather than to the value a host would give it.
          '';
        };

        binary = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Executable taken from the evaluated Home Manager profile.";
        };

        systems = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = config.systems;
          description = "Systems this app is published for.";
        };
      };
    };

  evaluate =
    {
      pkgs,
      pkgs-stable,
      selfPackages,
      system,
    }:
    app:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          home = {
            inherit username homeDirectory;
            stateVersion = "24.05";
            enableNixpkgsReleaseCheck = false;
          };
          # A portable wrapper never activates a generation, so the parts of
          # Home Manager that only make sense for an owned home stay off.
          programs.home-manager.enable = false;
          manual.manpages.enable = false;
          news.display = "silent";
        }
        inputs.catppuccin.homeModules.catppuccin
        inputs.nix-index-database.homeModules.default
        inputs.spicetify-nix.homeManagerModules.default
        inputs.vicinae.homeManagerModules.default
        inputs.zen-browser.homeModules.beta
        inputs._1password-shell-plugins.hmModules.default
        homeModules.catppuccin
      ]
      ++ map (feature: homeModules.${feature}) app.modules;
      extraSpecialArgs = inputs // {
        inherit
          pkgs-stable
          selfPackages
          system
          username
          ;
        catppuccin = config.seele.catppuccin;
        configName = "portable";
        currentSystem = system;
        self-path = inputs.self.outPath;
      };
    };

  wrap =
    { pkgs, ... }@args:
    name: app:
    let
      hm = evaluate args app;
      files = hm.config.home-files;
      profile = hm.config.home.path;

      # Exported the way Home Manager writes its own session-variable file, so a
      # value that was written to be expanded by a shell still is.
      environment =
        hm.config.home.sessionVariables
        // lib.optionalAttrs (writesConfig hm) { XDG_CONFIG_HOME = configDirectory; };

      exports = lib.concatMapStringsSep "\n" (
        variable: ''export ${variable}="${toString environment.${variable}}"''
      ) (lib.attrNames environment);

      searchPath = lib.concatStringsSep ":" (hm.config.home.sessionPath ++ [ "${profile}/bin" ]);

      configDirectory = "\${SEELE_PORTABLE_HOME:-\${XDG_CACHE_HOME:-$HOME/.cache}/seele/portable}/${name}";
    in
    pkgs.writeShellScriptBin app.binary ''
      set -euo pipefail

      ${lib.optionalString (writesConfig hm) ''
        # Home Manager's generated tree is read-only, but the applications that
        # read it also write next to it -- shell universal variables, credential
        # files, caches keyed by config path. Materialising it as a symlink farm
        # in a stable per-user directory gives both: the managed files stay
        # store symlinks that follow this flake, and anything the application
        # creates for itself is a real file that survives the next run. Only
        # symlinks are cleared when the generation changes, so relinking cannot
        # take that state with it.
        configuration="${configDirectory}"
        if [ "$(${pkgs.coreutils}/bin/cat "$configuration/.seele-generation" 2>/dev/null || true)" != "${files}" ]; then
          ${pkgs.coreutils}/bin/mkdir -p "$configuration"
          ${pkgs.findutils}/bin/find "$configuration" -type l -delete
          ${pkgs.coreutils}/bin/cp -RsfT "${files}/.config" "$configuration"
          ${pkgs.findutils}/bin/find "$configuration" -type d -exec ${pkgs.coreutils}/bin/chmod u+rwx {} +
          printf '%s' "${files}" > "$configuration/.seele-generation"
        fi
      ''}

      export PATH="${searchPath}''${PATH:+:$PATH}"
      ${exports}

      exec ${profile}/bin/${app.binary} "$@"
    '';

  packagesFor =
    system:
    withSystem system (
      perSystemArgs:
      let
        args = {
          inherit (perSystemArgs) pkgs pkgs-stable;
          inherit system;
          selfPackages = perSystemArgs.config.packages;
        };
      in
      lib.mapAttrs (wrap args) (
        lib.filterAttrs (_: app: lib.elem system app.systems) config.seele.portable
      )
    );
in
{
  options.seele.portable = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule appModule);
    default = { };
    description = ''
      Applications published as flake packages that carry their own Seele
      configuration, so `nix run` reaches them on a host this flake does not
      manage. Each entry evaluates its Home Manager features standalone and
      wraps the resulting binary.
    '';
  };

  config.flake.packages = lib.genAttrs config.systems packagesFor;
}
