{ ... }:
let
  module = (
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Standalone portable evaluations do not activate XDG user directories.
      # Keep their defaults relative to the runtime home, not the build sentinel.
      directory =
        name: fallback:
        if config.xdg.userDirs.enable && config.xdg.userDirs.${name} != null then
          config.xdg.userDirs.${name}
        else
          "~/${fallback}";
      bookmark = key: name: fallback: {
        on = [
          "g"
          key
        ];
        run = "cd ${lib.escapeShellArg (directory name fallback)}";
        desc = "Go to ${fallback}";
      };

      # Yazi's archive previewer and its `extract` plugin run `7zz` from the
      # wrapper's PATH, which nixpkgs prefixes with its own 7-Zip; `pack`
      # gets the same binary by store path. The free build lists a RAR but
      # leaves each compressed member empty, so take the one with the RAR
      # decoder: its unRAR restriction only forbids recreating the RAR
      # compressor. Extraction trusts 7-Zip to keep entries inside the target
      # (`..`, absolute names and links that leave it are refused); 25.01's
      # CVE-2025-55188 fix is what makes that hold for links.
      sevenZip =
        assert lib.assertMsg (lib.versionAtLeast pkgs._7zz-rar.version "25.01")
          "Yazi extraction relies on the symbolic link checks 7-Zip added in 25.01";
        pkgs._7zz-rar;
      # Yazi replaces `%s` with the selected (or hovered) paths, each quoted.
      extract = lib.escapeShellArg "${config.programs.yazi.package}/bin/ya pub extract --list %s";
    in
    {
      programs.yazi = {
        enable = true;
        package = pkgs.yazi.override { _7zz = sevenZip; };
        enableFishIntegration = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;
        shellWrapperName = "y";
        plugins = with pkgs; {
          git = {
            package = yaziPlugins.git;
            setup = true;
          };
          glow = yaziPlugins.glow.overrideAttrs (old: {
            # The pinned plugin predates Yazi 26.9's command and preview APIs.
            postPatch = (old.postPatch or "") + ''
              substituteInPlace main.lua \
                --replace-fail '-- Set a fixed width of 50 characters for the preview' '-- Wrap Markdown to the preview pane width.' \
                --replace-fail 'local preview_width = 55' 'local preview_width = job.area.w' \
                --replace-fail '-- Use fixed width instead of job.area.w' '-- Match the current pane width' \
                --replace-fail '"dark",' 'os.getenv("GLAMOUR_STYLE") or "dark",' \
                --replace-fail ':args({' ':arg({' \
                --replace-fail 'tostring(job.file.url)' 'tostring(job.file.path)' \
                --replace-fail 'require("code").peek(job)' 'require("code"):peek(job)' \
                --replace-fail 'ya.mgr_emit' 'ya.emit' \
                --replace-fail 'ya.preview_widgets' 'ya.preview_widget'
            '';
          });
          diff = yaziPlugins.diff;
          chmod = yaziPlugins.chmod;
          lazygit = yaziPlugins.lazygit;
          pack = pkgs.linkFarm "pack.yazi" {
            "main.lua" = pkgs.replaceVars ./_yazi/pack.lua { sevenzip = lib.getExe sevenZip; };
          };
        };
        extraPackages = with pkgs; [
          git
          glow
          diffutils
          coreutils
        ];
        settings.plugin = {
          prepend_previewers = [
            {
              url = "*.md";
              run = "glow";
            }
            {
              url = "*.markdown";
              run = "glow";
            }
          ];
          prepend_fetchers = [
            {
              url = "*";
              run = "git";
              group = "git";
            }
            {
              url = "*/";
              run = "git";
              group = "git";
            }
          ];
        };
        keymap.mgr.prepend_keymap = [
          (bookmark "d" "download" "Downloads")
          (bookmark "o" "documents" "Documents")
          (bookmark "p" "pictures" "Pictures")
          {
            on = [
              "g"
              "D"
            ];
            run = "plugin diff";
            desc = "Copy diff between selected and hovered files";
          }
          {
            on = [
              "c"
              "m"
            ];
            run = "plugin chmod";
            desc = "Change permissions of selected files";
          }
          {
            on = "C";
            run = "plugin pack";
            desc = "Pack selected files into a new archive";
          }
          {
            # The same path the archive opener takes, so passwords, nested
            # tarballs and the new sibling folder all stay Yazi's own. An
            # archive holding a single entry yields that entry instead.
            on = "E";
            run = "shell ${extract}";
            desc = "Extract selected archives beside them";
          }
        ];
      };
    }
  );
in
{
  flake.modules.homeManager."yazi" = module;

  seele.portable.yazi = {
    modules = [
      "yazi"
      "bat"
      "fd"
      "ripgrep"
      "lazygit"
    ];
  };
}
