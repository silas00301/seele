{ ... }:
let
  module = ({
    programs.aerospace.settings = {
      on-window-detected = [
        {
          "if".app-id = "com.jetbrains.intellij";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 1" ];
        }
        {
          "if".app-id = "com.jetbrains.rider";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 1" ];
        }
        {
          "if".app-id = "com.jetbrains.WebStorm";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 2" ];
        }
        {
          "if".app-id = "com.mitchellh.ghostty";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 3" ];
        }
        {
          "if" = {
            app-id = "com.microsoft.teams2";
            app-name-regex-substring = "^((Activity|Settings|Chat | .*|Teams and Channels | .*|Calendar|Calls|Copilot|OneDrive)?( \\| ))?Microsoft Teams$";
          };
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 5" ];
        }
        {
          "if".app-id = "com.microsoft.Outlook";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 6" ];
        }
        {
          "if".app-id = "com.spotify.client";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 7" ];
        }
        {
          "if".app-id = "Mattermost.Desktop";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 8" ];
        }
        {
          "if".app-id = "com.microsoft.teams2";
          check-further-callbacks = true;
          run = [ "move-node-to-workspace 9" ];
        }
        {
          "if".app-id = "app.zen-browser.zen";
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 10" ];
        }
      ];
    };
  });
in
{
  flake.modules.homeManager."aerospace-asuka" = module;
}
