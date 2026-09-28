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
      };
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-webui = {
      url = "github:nesquena/hermes-webui";
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
      nix-github-actions,
      hermes-agent,
      hermes-webui,
      systems,
      ...
    }:
    let
      # Modules every host gets. Importing a module only declares its
      # options; nothing is enabled until a host or user config sets it.
      sharedModules = [
        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        hermes-agent.nixosModules.default
        hermes-webui.nixosModules.default
        {
          home-manager = {
            sharedModules = [
              agenix.homeManagerModules.default
              hermes-agent.homeManagerModules.default
            ];
            users.emmberkat.imports = [
              self.nixosModules.neovim
              ./user/emmberkat
            ];
          };
        }
      ];
      mkHost =
        modules:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = sharedModules ++ modules;
        };
    in
    rec {
      nixosModules.neovim = ./modules/neovim;
      formatter = nixpkgs.lib.genAttrs (import systems) (
        system: (import nixpkgs { inherit system; }).nixfmt-tree
      );
      checks = nixpkgs.lib.genAttrs (import systems) (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            statix check ${self}
            touch $out
          '';
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") (
          nixpkgs.lib.mapAttrs' (
            name: cfg: nixpkgs.lib.nameValuePair "nixos-${name}" cfg.config.system.build.toplevel
          ) nixosConfigurations
        )
      );
      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = nixpkgs.lib.getAttrs [ "x86_64-linux" ] self.checks;
      };
      nixosConfigurations = {

        crystal = mkHost [
          ./system/crystal
          {
            home-manager.users.emmberkat = {
              imports = [ ./system/crystal/user/emmberkat ];
              emmberkat.ui.enable = true;
            };
          }
        ];

        catalyst = mkHost [
          { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
          ./system/catalyst
          nix-minecraft.nixosModules.minecraft-servers
          {
            home-manager.users.emmberkat.emmberkat.neovim = {
              java.enable = false;
              kotlin.enable = false;
              rust.enable = false;
            };
          }
        ];

        emmberdeck = mkHost [
          ./system/emmberdeck
          {
            home-manager.users.emmberkat.emmberkat = {
              ui.enable = true;
              neovim = {
                java.enable = false;
                kotlin.enable = false;
                rust.enable = false;
              };
            };
          }
        ];

        kuzco = mkHost [
          ./system/kuzco
          {
            home-manager.users.emmberkat.emmberkat.neovim = {
              java.enable = false;
              kotlin.enable = false;
              rust.enable = false;
            };
          }
        ];

      };
    };
}
