{ config, lib, ... }:
let
  notes = config.seele.notes;
  module =
    { selfPackages, ... }:
    {
      home.packages = [ selfPackages.seele-notes ];

      # An optional starting point, not a setting the application enforces. The
      # directory picker writes the user's own choice to its private settings
      # file, and that choice wins over this one. Leaving `vault` unset ships no
      # file at all, so the application opens on its picker instead of on a path
      # this flake guessed.
      xdg.configFile = lib.mkIf (notes.vault != null) {
        "seele-notes/config.json".text = builtins.toJSON {
          inherit (notes) vault directory attachments;
        };
      };
    };
in
{
  options.seele.notes = {
    vault = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/silash/Documents/Main";
      description = ''
        The Obsidian vault Seele Notes captures into. Null leaves the choice to
        the application's directory picker.
      '';
    };

    directory = lib.mkOption {
      type = lib.types.str;
      default = "Inbox";
      description = "The vault-relative folder new captures are written to.";
    };

    attachments = lib.mkOption {
      type = lib.types.str;
      default = "Attachments";
      description = "The folder below the capture folder that holds recordings.";
    };
  };

  config.flake.modules.homeManager.seele-notes = module;
}
