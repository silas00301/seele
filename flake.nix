{
  description = "Seele: my Nix and Home Manager configuration";

  inputs = {
    self.submodules = true;

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

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    quickshell.url = "github:outfoxxed/quickshell";
    quickshell.inputs.nixpkgs.follows = "nixpkgs";

    seele-shell.url = ./seele-shell;
    seele-shell.inputs.nixpkgs.follows = "nixpkgs";
    seele-shell.inputs.quickshell.follows = "quickshell";

    # Upstream ONNX/CUDA build and Nix Git-dependency hash fixes after v1.0.1.
    voxtype.url = "github:peteonrails/voxtype/320a737e5d3c8662e0ec7de95f75407baa784d82";
    voxtype.inputs.nixpkgs.follows = "nixpkgs";

    vicinae.url = "github:vicinaehq/vicinae";

    nixvim.url = "github:nix-community/nixvim";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    zjstatus.url = "github:dj95/zjstatus";

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
