{ inputs, ... }:
let
  sourceFiles = file: builtins.filter (path: libPath path) [ (toString file) ];
  libPath = path: builtins.match "/.*" path != null;
  sources = option: builtins.concatMap (definition: sourceFiles definition.file) option.definitionsWithLocations;
  settings =
    lib: scope: options:
    let
      walk =
        path: depth: tree:
        if depth > 4 || !builtins.isAttrs tree then
          [ ]
        else if lib.isOption tree then
          lib.optional (lib.last path == "enable" && tree.isDefined && builtins.isBool tree.value) {
            kind = "setting";
            key = "${scope}.${lib.concatStringsSep "." path}";
            value = if tree.value then "enabled" else "disabled";
            sources = sources tree;
          }
        else
          lib.concatMap (name: walk (path ++ [ name ]) (depth + 1) tree.${name}) (
            builtins.attrNames tree
          );
    in
    lib.concatMap (name: walk [ name ] 0 (options.${name} or { })) [
      "programs"
      "services"
    ];
  packages =
    lib: scope: option:
    lib.concatMap (
      definition:
      map (package: {
        kind = "package";
        key = "${scope}.package.${lib.getName package}";
        value = "Directly included in ${scope} packages";
        sources = sourceFiles definition.file;
      }) definition.value
    ) option.definitionsWithLocations;
  systemModule =
    {
      config,
      lib,
      options,
      username,
      ...
    }:
    {
      home-manager.users.${username}.seele.configurationInspector.systemRows =
        settings lib "system" options
        ++ packages lib "system" options.environment.systemPackages;
    };
in
{
  flake.modules.nixos.configuration-inspector = systemModule;
  flake.modules.darwin.configuration-inspector = systemModule;
  flake.modules.homeManager.configuration-inspector =
    {
      config,
      lib,
      options,
      pkgs,
      selfPackages,
      ...
    }:
    let
      shortcutOption = options.wayland.windowManager.hyprland.extraConfig or null;
      shortcuts =
        if shortcutOption == null then
          [ ]
        else
          lib.concatMap (
            definition:
            lib.concatMap (
              line:
              let
                match = builtins.match ''.*hl\.bind\("([^"]+)".*description = "([^"]+)".*'' line;
              in
              lib.optional (match != null) {
                kind = "shortcut";
                key = "shortcut.${builtins.elemAt match 0}";
                value = builtins.elemAt match 1;
                sources = sourceFiles definition.file;
              }
            ) (lib.splitString "\n" definition.value)
          ) shortcutOption.definitionsWithLocations;
      rows =
        settings lib "home" options
        ++ packages lib "home" options.home.packages
        ++ shortcuts
        ++ config.seele.configurationInspector.systemRows;
    in
    {
      options.seele.configurationInspector.systemRows = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        internal = true;
        description = "Safe system metadata supplied by the matching host feature.";
      };
      config = {
        home.packages = [ selfPackages.config-tools ];
        home.sessionVariables.SEELE_INSPECT_EDITOR = "${selfPackages.nixvim}/bin/nvim";
        xdg.configFile."seele-inspect/catalog.json".source = pkgs.writeText "seele-inspect.json" (
          builtins.toJSON {
            version = 1;
            sourceRoot = toString inputs.self.outPath;
            inherit rows;
          }
        );
      };
    };
}
