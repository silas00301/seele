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
        homeModules.catppuccin
        homeModules.determinate
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

      configDirectory = "\${SEELE_PORTABLE_HOME:-\${XDG_CACHE_HOME:-$HOME/.cache}/seele/portable}/${name}";
      manifest = pkgs.writeText "seele-${name}-launch.json" (
        builtins.toJSON {
          version = 1;
          program = "${profile}/bin/${app.binary}";
          path = hm.config.home.sessionPath ++ [ "${profile}/bin" ];
          environment = lib.mapAttrs (_: value: toString value) (
            hm.config.home.sessionVariables
            // lib.optionalAttrs (writesConfig hm) { XDG_CONFIG_HOME = configDirectory; }
          );
          configuration =
            if writesConfig hm then
              {
                source = "${files}/.config";
                destination = configDirectory;
              }
            else
              null;
        }
      );
    in
    pkgs.runCommand "seele-portable-${name}"
      {
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
        meta.mainProgram = app.binary;
      }
      ''
        mkdir -p "$out/bin"
        makeWrapper ${args.selfPackages.config-tools}/bin/seele-launch "$out/bin/${app.binary}" \
          --add-flags ${lib.escapeShellArg (toString manifest)}
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

  config.perSystem = { config, ... }: {
    checks.portable-config = config.packages.config-tools;
  };

  config.flake.packages = lib.genAttrs config.systems packagesFor;
}
