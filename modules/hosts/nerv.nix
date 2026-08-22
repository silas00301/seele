{
  config,
  inputs,
  withSystem,
  ...
}:
let
  inherit (config.seele) catppuccin;
  username = config.seele.hosts.nerv.username;
  modules = config.flake.modules;
in
{
  flake.nixosConfigurations.nerv = withSystem "x86_64-linux" (
    perSystemArgs:
    let
      perSystem = perSystemArgs.config;
      system = "x86_64-linux";
      moduleArgs = inputs // {
        inherit catppuccin system username;
        currentSystem = system;
        selfPackages = perSystem.packages;
        self-path = inputs.self.outPath;
      };
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = moduleArgs;
      modules = [
        { inherit username; }
        modules.nixos.linux
        modules.nixos.common
        modules.nixos.nerv
        inputs.noctalia.nixosModules.default
        inputs.catppuccin.nixosModules.catppuccin
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupCommand = perSystemArgs.pkgs.writeShellScript "home-manager-backup" ''
              exec ${perSystemArgs.pkgs.coreutils}/bin/mv --backup=numbered -- "$1" "$1.bak"
            '';
            users.${username}.imports = [
              modules.homeManager.common
              modules.homeManager.linux
              modules.homeManager.nerv
              inputs.catppuccin.homeModules.catppuccin
              inputs.noctalia.homeModules.default
              inputs.spicetify-nix.homeManagerModules.default
              inputs.vicinae.homeManagerModules.default
              inputs.zen-browser.homeModules.beta
              inputs.nix-index-database.homeModules.default
              inputs._1password-shell-plugins.hmModules.default
            ];
            extraSpecialArgs = moduleArgs // {
              inherit (perSystemArgs) pkgs-stable;
              configName = "nerv";
            };
          };
        }
      ];
    }
  );
}
