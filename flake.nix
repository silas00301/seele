{
  description = "Seele: my Nix and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-stable-nixos.url = "github:NixOS/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";

    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Determinate Nix, the Nix distribution `nerv` runs. Deliberately without a
    # nixpkgs `follows`: the override rebuilds Determinate's own artifacts
    # instead of fetching the ones FlakeHub Cache already has, which upstream
    # advises against.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    _1password-shell-plugins.url = "github:1Password/shell-plugins";
    _1password-shell-plugins.inputs.nixpkgs.follows = "nixpkgs";

    quickshell.url = "github:outfoxxed/quickshell";
    quickshell.inputs.nixpkgs.follows = "nixpkgs";

    seele-shell.url = "git+file:./seele-shell";
    seele-shell.inputs.nixpkgs.follows = "nixpkgs";
    seele-shell.inputs.quickshell.follows = "quickshell";

    vicinae.url = "github:vicinaehq/vicinae";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    zjstatus.url = "github:dj95/zjstatus";

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    t3code-nightly-release = {
      url = "file+https://api.github.com/repos/pingdotgg/t3code/releases?per_page=20";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
