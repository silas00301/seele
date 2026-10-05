{ lib }:
let
  feature = import ../configuration-inspector.nix { inputs.self.outPath = "/fixture-source"; };
  option = value: file: {
    _type = "option";
    isDefined = true;
    inherit value;
    definitionsWithLocations = [ { inherit value file; } ];
  };
  result = feature.flake.modules.homeManager.configuration-inspector {
    inherit lib;
    config = {
      home.homeDirectory = "/fixture-home";
      seele.configurationInspector.systemRows = [ ];
    };
    options = {
      programs.fish.enable = option true "/fixture-source/modules/fish.nix";
      services.example.enable = option false "/upstream/service.nix";
      home.packages = option [ { name = "fish-1.0"; } ] "/fixture-source/modules/packages.nix";
      wayland.windowManager.hyprland.extraConfig = option ''
        hl.bind("SUPER + N", hl.dsp.exec_cmd("secret-command-arguments"), { description = "Notifications" })
      '' "/fixture-source/modules/hypr.nix";
    };
    selfPackages = {
      config-tools = "/native-tools";
      nixvim = "/editor";
    };
    pkgs.writeText = name: text: text;
  };
  catalog = builtins.fromJSON result.config.xdg.configFile."seele-inspect/catalog.json".source;
  row = key: lib.findFirst (item: item.key == key) null catalog.rows;
in
assert catalog.version == 1;
assert (row "home.programs.fish.enable").value == "enabled";
assert (row "home.services.example.enable").value == "disabled";
assert (row "home.package.fish").sources == [ "/fixture-source/modules/packages.nix" ];
assert (row "shortcut.SUPER + N").value == "Notifications";
assert !(lib.hasInfix "secret-command-arguments" (builtins.toJSON catalog));
assert catalog.sourceRoot == "/fixture-source";
catalog
