{
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "https://comfyui.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "crystal:1ejOpnHE9Io7242e2uHtGeN2Mtcey67OyDp7qNwk5Rs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    systems.url = "github:nix-systems/default";
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        systems.follows = "systems";
      };
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comfyui = {
      url = "github:utensils/comfyui-nix";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      nix-minecraft,
      jovian,
      systems,
      comfyui,
      ...
    }:
    rec {
      nixosModules.neovim = ./modules/neovim;
      formatter = nixpkgs.lib.genAttrs (import systems) (
        system: (import nixpkgs { inherit system; }).nixfmt-tree
      );
      checks = nixpkgs.lib.genAttrs (import systems) (system: {
        inherit (import nixpkgs { inherit system; }) statix;
      });
      nixosConfigurations = {

        crystal = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./system/crystal
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            {
              home-manager.users.emmberkat = {
                imports = [
                  agenix.homeManagerModules.default
                  nixosModules.neovim
                  ./user/emmberkat
                  ./system/crystal/user/emmberkat
                ];
              };
            }
          ];
        };

        catalyst = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            {
              nixpkgs.overlays = [
                nix-minecraft.overlay
                comfyui.overlays.default
              ];
            }
            ./system/catalyst
            comfyui.nixosModules.default
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            nix-minecraft.nixosModules.minecraft-servers
            {
              home-manager.users.emmberkat = {
                imports = [
                  agenix.homeManagerModules.default
                  nixosModules.neovim
                  ./user/emmberkat
                ];
                emmberkat.neovim = {
                  java.enable = false;
                  kotlin.enable = false;
                  rust.enable = false;
                };
              };
            }
          ];
        };

      };
    };
}
