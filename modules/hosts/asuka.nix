{
  config,
  inputs,
  withSystem,
  ...
}:
let
  inherit (config.seele) catppuccin;
  username = config.seele.hosts.asuka.username;
  modules = config.flake.modules;
in
{
  flake.darwinConfigurations.asuka = withSystem "aarch64-darwin" (
    perSystemArgs:
    let
      perSystem = perSystemArgs.config;
      system = "aarch64-darwin";
      moduleArgs = inputs // {
        inherit catppuccin system username;
        currentSystem = system;
        selfPackages = perSystem.packages;
        self-path = inputs.self.outPath;
      };
    in
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = moduleArgs;
      modules = [
        {
          inherit username;
          system.stateVersion = 5;
          system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
        }
        modules.darwin.darwin
        modules.darwin.common
        modules.darwin.asuka
        inputs.stylix.darwinModules.stylix
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "bak";
            users.${username}.imports = [
              modules.homeManager.common
              modules.homeManager.darwin
              modules.homeManager.asuka
              inputs.catppuccin.homeModules.catppuccin
              inputs.spicetify-nix.homeManagerModules.default
              inputs.vicinae.homeManagerModules.default
              inputs.zen-browser.homeModules.beta
              inputs.nix-index-database.homeModules.default
              inputs._1password-shell-plugins.hmModules.default
            ];
            extraSpecialArgs = moduleArgs // {
              inherit (perSystemArgs) pkgs-stable;
              configName = "asuka";
            };
          };
        }
      ];
    }
  );

  flake.darwinPackages = config.flake.darwinConfigurations.asuka.pkgs;
}
