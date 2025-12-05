{
  nixConfig = {
    extra-substituters = [
      "s3://emmberkat-nix-cache?region=sea&endpoint=minio.emmberkat.com"
    ];
    extra-trusted-public-keys = [
      "crystal:1ejOpnHE9Io7242e2uHtGeN2Mtcey67OyDp7qNwk5Rs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
                ];
              };
            }
          ];
        };
        catalyst = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./system/catalyst
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
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
