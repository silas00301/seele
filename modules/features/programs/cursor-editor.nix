{ ... }:
let
  module =
    {
      config,
      configName,
      lib,
      pkgs,
      ...
    }:
    {
      programs.cursor = {
        enable = true;
        # Portable evaluations only materialize .config, not ~/.cursor. Point
        # the launcher at Home Manager's immutable extension bundle instead.
        package =
          if configName == "portable" then
            pkgs.code-cursor.override {
              commandLineArgs = lib.escapeShellArgs [
                "--extensions-dir"
                (toString config.home.file.".cursor/extensions".source)
              ];
            }
          else
            pkgs.code-cursor;
        mutableExtensionsDir = false;
        profiles.default = {
          enableUpdateCheck = false;
          enableExtensionUpdateCheck = false;
          extensions = with pkgs.vscode-extensions; [
            vscodevim.vim
            jnoortheen.nix-ide
          ];
          userSettings = {
            "telemetry.telemetryLevel" = "off";
            "workbench.enableExperiments" = false;
            "extensions.autoUpdate" = false;
            "editor.fontFamily" = "Maple Mono NF CN";
            "editor.fontSize" = 14;
            "editor.lineNumbers" = "relative";
            "editor.tabSize" = 2;
            "editor.insertSpaces" = true;
            "editor.minimap.enabled" = false;
            "editor.formatOnSave" = true;
            "editor.inlayHints.enabled" = "on";
            "vim.leader" = "<space>";
            "vim.smartcase" = true;
            "vim.incsearch" = true;
            "nix.enableLanguageServer" = true;
            "nix.serverPath" = lib.getExe pkgs.nixd;
            "nix.serverSettings".nixd.formatting.command = [ (lib.getExe pkgs.nixfmt) ];
            "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
          };
        };
      };

      catppuccin.cursor.profiles.default = {
        enable = true;
        icons.enable = true;
      };

      home.packages = [ pkgs.maple-mono.NF-CN ];
    };
in
{
  # `cursor` is already the Linux pointer theme feature.
  flake.modules.homeManager.cursor-editor = module;

  # Darwin stores Cursor settings in Library/Application Support, outside the
  # portable builder's .config contract.
  seele.portable.cursor = {
    modules = [ "cursor-editor" ];
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
