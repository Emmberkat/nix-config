{
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "https://nix.emmberkat.com"
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "crystal:1ejOpnHE9Io7242e2uHtGeN2Mtcey67OyDp7qNwk5Rs="
      "ci.emmberkat.com-1:zKoUaHn7DmqApO1CmvMyVtRK0c1ZliEdrYn8Yq+DtO0="
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        # Share the top-level uv2nix tooling instead of locking a second copy.
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        pyproject-build-systems.follows = "pyproject-build-systems";
      };
    };
    hermes-webui = {
      url = "github:nesquena/hermes-webui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nextcloud-mcp-server = {
      url = "github:cbcoutinho/nextcloud-mcp-server/v0.198.0";
      flake = false;
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
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      nextcloud-mcp-server,
      ...
    }:
    let
      # Packages not in nixpkgs, exposed as flake outputs and via
      # overlays.default (applied to every host).
      mkPackages = pkgs: {
        nextcloud-mcp-server = pkgs.callPackage ./pkgs/nextcloud-mcp-server.nix {
          src = nextcloud-mcp-server;
          inherit pyproject-nix uv2nix pyproject-build-systems;
        };
      };

      # Modules every host gets. Importing a module only declares its
      # options; nothing is enabled until a host or user config sets it.
      sharedModules = [
        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        hermes-agent.nixosModules.default
        hermes-webui.nixosModules.default
        { nixpkgs.overlays = [ self.overlays.default ]; }
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
      overlays.default = final: _prev: mkPackages final;
      packages.x86_64-linux = mkPackages nixpkgs.legacyPackages.x86_64-linux;
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
          deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            deadnix --fail ${self}
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
              emmberkat = {
                ui.enable = true;
                neovim = {
                  java.enable = true;
                  kotlin.enable = true;
                  python.enable = true;
                  rust.enable = true;
                };
              };
            };
          }
        ];

        catalyst = mkHost [
          { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
          ./system/catalyst
          nix-minecraft.nixosModules.minecraft-servers
        ];

        emmberdeck = mkHost [
          ./system/emmberdeck
          {
            home-manager.users.emmberkat.emmberkat.ui.enable = true;
          }
        ];

        kuzco = mkHost [
          ./system/kuzco
        ];

        lattice = mkHost [
          ./system/lattice
          {
            home-manager.users.emmberkat = {
              imports = [ ./system/lattice/user/emmberkat ];
              emmberkat = {
                ui.enable = true;
                neovim = {
                  java.enable = true;
                  kotlin.enable = true;
                  python.enable = true;
                  rust.enable = true;
                };
              };
            };
          }
        ];

      };
    };
}
