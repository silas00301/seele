{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
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
