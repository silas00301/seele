{ ... }:
let
  module = (
    {
      config,
      ...
    }:
    {
      programs.zen-browser =
        let
          mkLockedAttrs = builtins.mapAttrs (
            _: value: {
              Value = value;
              Status = "locked";
            }
          );
        in
        {
          enable = true;
          policies = {
            RequestedLocales = [
              "en-US"
              "de"
              "ja"
            ];
            AutofillAddressEnabled = false;
            AutofillCreditCardEnabled = false;
            DisableAppUpdate = true;
            DisableFeedbackCommands = true;
            DisableFirefoxStudies = true;
            DisablePocket = true;
            DisableTelemetry = true;
            DontCheckDefaultBrowser = true;
            NoDefaultBookmarks = true;
            PasswordManagerEnabled = false;
            OfferToSaveLogins = false;
            EnableTrackingProtection = {
              Value = true;
              Locked = true;
              Cryptomining = true;
              Fingerprinting = true;
            };
            SearchEngines = {
              Default = "Startpage";
              Add = [
                {
                  Name = "Startpage";
                  URLTemplate = "https://startpage.com/sp/search?query={searchTerms}";
                  IconURL = "https://startpage.com/sp/cdn/favicons/favicon-gradient.ico";
                  SuggestURLTemplate = "https://www.startpage.com/osuggestions?q=%s";
                }
              ];
            };
            Preferences = mkLockedAttrs {
              "devtools.theme" = "dark";
              "zen.view.compact.hide-toolbar" = true;
              "zen.view.compact.enable-at-startup" = true;
              "zen.view.use-single-toolbar" = false;
            };
            ExtensionSettings = {
              "uBlock0@raymondhill.net" = {
                installation_mode = "force_installed";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              };
              "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
                installation_mode = "force_installed";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
              };
              "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
                installation_mode = "force_installed";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi/";
              };
              "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = {
                installation_mode = "force_installed";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/refined-github-/latest.xpi/";
              };
              "{bbb880ce-43c9-47ae-b746-c3e0096c5b76}" = {
                installation_mode = "force_installed";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-web-file-icons/latest.xpi/";
              };
            };
          };
          profiles."default" = {
            settings = {
              "zen.view.compact.hide-toolbar" = true;
              "zen.view.compact.enable-at-startup" = true;
              "zen.view.use-single-toolbar" = false;
            };
            containersForce = true;
            containers = {
              Private = {
                color = "purple";
                icon = "fingerprint";
                id = 1;
              };
              School = {
                color = "red";
                icon = "circle";
                id = 2;
              };
              Work = {
                color = "blue";
                icon = "briefcase";
                id = 3;
              };
            };
            spacesForce = true;
            spaces =
              let
                containers = config.programs.zen-browser.profiles."default".containers;
              in
              {
                "Private" = {
                  id = "1e67f2a8-891f-46f9-9473-11edf4682941";
                  icon = "chrome://browser/skin/zen-icons/selectable/people.svg";
                  container = containers."Private".id;
                  position = 1000;
                  theme = {
                    type = "solid";
                    colors = [
                      {
                        red = 24;
                        green = 24;
                        blue = 37;
                      }
                    ];
                  };
                };
                "School" = {
                  id = "5a1bfdd1-0dce-4b11-b818-a54d074a1e12";
                  icon = "chrome://browser/skin/zen-icons/selectable/school.svg";
                  container = containers."School".id;
                  position = 2000;
                  theme = {
                    type = "solid";
                    colors = [
                      {
                        red = 24;
                        green = 24;
                        blue = 37;
                      }
                    ];
                  };
                };
                "Work" = {
                  id = "af11e9bd-310e-4a24-81c9-8ead70a71abf";
                  icon = "chrome://browser/skin/zen-icons/selectable/briefcase.svg";
                  container = containers."Work".id;
                  position = 3000;
                  theme = {
                    type = "solid";
                    colors = [
                      {
                        red = 24;
                        green = 24;
                        blue = 37;
                      }
                    ];
                  };
                };
              };
          };
        };
      xdg.mimeApps =
        let
          browser = "zen-beta.desktop";

          associations = builtins.listToAttrs (
            map
              (name: {
                inherit name;
                value = browser;
              })
              [
                "application/x-extension-shtml"
                "application/x-extension-xhtml"
                "application/x-extension-html"
                "application/x-extension-xht"
                "application/x-extension-htm"
                "x-scheme-handler/unknown"
                "x-scheme-handler/mailto"
                "x-scheme-handler/chrome"
                "x-scheme-handler/about"
                "x-scheme-handler/https"
                "x-scheme-handler/http"
                "application/xhtml+xml"
                "application/json"
                "text/plain"
                "text/html"
              ]
          );
        in
        {
          associations.added = associations;
          defaultApplications = associations;
        };
    }
  );
in
{
  flake.modules.homeManager."zen-browser" = module;
}
