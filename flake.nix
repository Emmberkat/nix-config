{
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "s3://emmberkat-nix-cache?region=sea&endpoint=minio.emmberkat.com"

    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "crystal:1ejOpnHE9Io7242e2uHtGeN2Mtcey67OyDp7qNwk5Rs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix-minecraft = {
      # Switch back to github:Infinidoge/nix-minecraft once
      # https://github.com/Infinidoge/nix-minecraft/pull/161
      # is merged.
      url = "github:Emmberkat/nix-minecraft/neoforge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      nix-minecraft,
    }:
    rec {
      nixosModules.neovim = ./modules/neovim;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
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
              nixpkgs.overlays = [ nix-minecraft.overlay ];
            }
            ./system/catalyst
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
