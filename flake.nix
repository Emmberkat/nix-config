{
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "https://nix.emmberkat.com"
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "crystal:1ejOpnHE9Io7242e2uHtGeN2Mtcey67OyDp7qNwk5Rs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      nix-minecraft,
      nix-openclaw,
      systems,
      ...
    }:
    rec {
      nixosModules.neovim = ./modules/neovim;
      # whisperx pulls the whole PyTorch/CUDA stack: 14.57 GB across 225 store
      # paths, nearly a third of catalyst's closure. Nothing consumes it
      # programmatically -- Home Assistant's speech-to-text uses
      # wyoming-faster-whisper -- so it is exposed here for `nix run .#whisperx`
      # instead of being pinned into catalyst's system-path. CI builds
      # nixosConfigurations only, so this costs nothing on a PR.
      packages = nixpkgs.lib.genAttrs (import systems) (system: {
        whisperx =
          (import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          }).pkgsCuda.whisperx;
      });
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
            {
              nixpkgs.overlays = [
                nix-openclaw.overlays.default
              ];
            }
            ./system/crystal
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.users.emmberkat = {
                imports = [
                  agenix.homeManagerModules.default
                  nixosModules.neovim
                  nix-openclaw.homeManagerModules.openclaw
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
                nix-openclaw.overlays.default
              ];
            }
            ./system/catalyst
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            nix-minecraft.nixosModules.minecraft-servers
            {
              home-manager.useGlobalPkgs = true;
              home-manager.users.emmberkat = {
                imports = [
                  agenix.homeManagerModules.default
                  nixosModules.neovim
                  nix-openclaw.homeManagerModules.openclaw
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

        emmberdeck = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./system/emmberdeck
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

        kuzco = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./system/kuzco
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
