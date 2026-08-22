{ ... }:
let
  module = (
    { config, pkgs, ... }:

    let
      palette =
        (builtins.fromJSON (builtins.readFile "${config.catppuccin.sources.palette}/palette.json"))
        .${config.catppuccin.flavor}.colors;

      catppuccinTheme = pkgs.writeText "pi-catppuccin-${config.catppuccin.flavor}.json" (
        builtins.toJSON {
          "$schema" =
            "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
          name = "catppuccin";

          vars = builtins.mapAttrs (_: color: color.hex) palette;

          colors = {
            accent = config.catppuccin.accent;
            border = "surface2";
            borderAccent = config.catppuccin.accent;
            borderMuted = "surface1";
            success = "green";
            error = "red";
            warning = "yellow";
            muted = "subtext0";
            dim = "overlay0";
            text = "text";
            thinkingText = "subtext0";

            selectedBg = "surface1";
            scrollbarThumb = "surface2";
            userMessageBg = "surface0";
            userMessageText = "text";
            customMessageBg = "surface0";
            customMessageText = "text";
            customMessageLabel = config.catppuccin.accent;
            toolPendingBg = "mantle";
            toolSuccessBg = "mantle";
            toolErrorBg = "mantle";
            toolTitle = config.catppuccin.accent;
            toolOutput = "text";

            mdHeading = "mauve";
            mdLink = "blue";
            mdLinkUrl = "overlay2";
            mdCode = "green";
            mdCodeBlock = "text";
            mdCodeBlockBorder = "surface2";
            mdQuote = "subtext0";
            mdQuoteBorder = "overlay0";
            mdHr = "surface2";
            mdListBullet = config.catppuccin.accent;

            toolDiffAdded = "green";
            toolDiffRemoved = "red";
            toolDiffContext = "subtext0";

            syntaxComment = "overlay1";
            syntaxKeyword = "mauve";
            syntaxFunction = "blue";
            syntaxVariable = "rosewater";
            syntaxString = "green";
            syntaxNumber = "peach";
            syntaxType = "yellow";
            syntaxOperator = "sky";
            syntaxPunctuation = "overlay2";

            thinkingOff = "overlay0";
            thinkingMinimal = "overlay2";
            thinkingLow = "blue";
            thinkingMedium = "teal";
            thinkingHigh = "mauve";
            thinkingXhigh = "red";
            thinkingMax = "pink";
            bashMode = "peach";
          };

          export = {
            pageBg = "base";
            cardBg = "mantle";
            infoBg = "surface0";
          };
        }
      );
    in
    {
      programs.pi-coding-agent = {
        enable = true;

        settings = {
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.6-sol";
          defaultThinkingLevel = "high";

          theme = "catppuccin";
          themes = [ catppuccinTheme ];
          quietStartup = true;
          collapseChangelog = true;

          editorPaddingX = 1;
          outputPad = 1;
          autocompleteMaxVisible = 8;

          enabledModels = [
            "openai-codex/*"
          ];

          defaultProjectTrust = "ask";

          compaction = {
            enabled = true;
            reserveTokens = 24576;
            keepRecentTokens = 32768;
          };

          retry = {
            enabled = true;
            maxRetries = 3;
            baseDelayMs = 1500;

            provider = {
              maxRetries = 0;
              maxRetryDelayMs = 60000;
            };
          };

          steeringMode = "one-at-a-time";
          followUpMode = "one-at-a-time";

          transport = "auto";

          doubleEscapeAction = "tree";
          treeFilterMode = "no-tools";

          terminal = {
            showImages = true;
            imageWidthCells = 60;
            clearOnShrink = false;
          };

          images = {
            autoResize = true;
            blockImages = false;
          };

          markdown = {
            codeBlockIndent = "  ";
            mermaid = "streaming";
          };

          enableSkillCommands = true;

          enableInstallTelemetry = false;
          enableAnalytics = false;

          context = ''
            # Preferred Tooling

            Prefer my existing modern CLI tooling when appropriate.

            * Prefer Jujutsu (`jj`) over Git for day-to-day version-control operations when the repository is Jujutsu-backed.
            * Use Git when required for compatibility or when the repository is not using Jujutsu.
            * Prefer `gh` for GitHub operations.
            * Prefer modern CLI tools over their traditional equivalents where appropriate:

              * `rg` over `grep`
              * `fd` over `find`
              * `bat` over `cat` for human-readable output
              * `eza` over `ls` for interactive directory listings
              * `fzf` for fuzzy selection

            Respect project-local conventions when they conflict with these preferences. Do not install or introduce additional tools when an existing tool already covers the task.

          '';
        };
      };

      home.file."${config.programs.pi-coding-agent.configDir}/extensions/status-bar.ts".text =
        builtins.replaceStrings [ "@JJ@" ] [ "${pkgs.jujutsu}/bin/jj" ]
          (builtins.readFile ./_pi/status-bar.ts);
    }
  );
in
{
  flake.modules.homeManager."pi" = module;
}
