{ ... }:
let
  # Desktop entry ids rather than packages: a MIME association names the entry
  # that will open the file, and the applications themselves are configured by
  # their own feature leaves.
  editor = "seele-editor.desktop";
  fileManager = "seele-files.desktop";
  viewer = "imv.desktop";
  player = "mpv.desktop";
  reader = "org.pwmt.zathura.desktop";

  editorTypes = [
    "application/toml"
    "application/x-shellscript"
    "application/x-yaml"
    "application/yaml"
    "text/markdown"
    "text/plain"
    "text/x-log"
  ];

  imageTypes = [
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/jpeg"
    "image/png"
    "image/svg+xml"
    "image/tiff"
    "image/webp"
  ];

  videoTypes = [
    "video/mp4"
    "video/mpeg"
    "video/quicktime"
    "video/webm"
    "video/x-matroska"
    "video/x-msvideo"
  ];

  audioTypes = [
    "audio/aac"
    "audio/flac"
    "audio/mp4"
    "audio/mpeg"
    "audio/ogg"
    "audio/opus"
    "audio/x-wav"
  ];

  documentTypes = [
    "application/epub+zip"
    "application/pdf"
  ];

  directoryTypes = [ "inode/directory" ];

  module = (
    {
      config,
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      # The terminal applications are opened by the configured terminal through
      # explicit store paths, because a desktop entry is executed by whatever
      # launched it and must not depend on that process's PATH.
      inTerminal = command: "${pkgs.ghostty}/bin/ghostty -e ${command} %f";

      handle = entry: types: lib.genAttrs types (_: entry);

      associations =
        handle editor editorTypes
        // handle viewer imageTypes
        // handle player (videoTypes ++ audioTypes)
        // handle reader documentTypes
        // handle fileManager directoryTypes;
    in
    {
      xdg.mimeApps = {
        enable = true;
        associations.added = associations;
        defaultApplications = associations;
      };

      # Terminal applications own two of these defaults, and neither ships a
      # desktop entry that opens in this desktop's terminal, so the entries the
      # associations name are declared here beside them.
      xdg.desktopEntries = {
        seele-editor = {
          name = "Neovim";
          genericName = "Text editor";
          comment = "Edit a file in the configured Neovim";
          exec = inTerminal "${selfPackages.nixvim}/bin/nvim";
          icon = "nvim";
          terminal = false;
          startupNotify = false;
          categories = [
            "Utility"
            "TextEditor"
          ];
          mimeType = editorTypes;
        };

        seele-files = {
          name = "Files";
          genericName = "File manager";
          comment = "Browse a directory in Yazi";
          exec = inTerminal "${config.programs.yazi.package}/bin/yazi";
          icon = "system-file-manager";
          terminal = false;
          startupNotify = false;
          categories = [
            "Utility"
            "FileTools"
            "FileManager"
          ];
          mimeType = directoryTypes;
        };
      };
    }
  );
in
{
  flake.modules.homeManager."default-applications" = module;
}
