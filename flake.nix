{
  nixConfig = {
    extra-substituters = [
      "s3://emmberkat-nix-cache?region=us-east-1&endpoint=minio.emmberkat.com"
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
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      nixosConfigurations = {
        crystal = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./system/crystal
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            {
              home-manager.users.emmberkat = ./user/emmberkat;
              home-manager.extraSpecialArgs = {
                agenix = agenix;
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
              home-manager.users.emmberkat = ./user/emmberkat;
              home-manager.extraSpecialArgs = {
                agenix = agenix;
              };
            }
          ];
        };
      };
    };
}
