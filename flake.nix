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
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
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
      systems,
      ...
    }:
    rec {
      nixosModules.neovim = ./modules/neovim;
      formatter = nixpkgs.lib.genAttrs (import systems) (
        system: (import nixpkgs { inherit system; }).nixfmt-tree
      );
      checks = nixpkgs.lib.genAttrs (import systems) (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          # Every .age file in the repo must have an agenix-rules.nix entry,
          # and no rule may reference a file that does not exist.
          src = ./.;
          rules = import ./agenix-rules.nix;
          # Recursively collect .age files as paths relative to the repo root.
          # (Building the relative path during the walk avoids any dependence
          # on how `src` is stored, which would otherwise need prefix-stripping.)
          findAgeFiles =
            dir:
            rel:
            let
              entries = builtins.readDir dir;
            in
            builtins.concatMap (name:
              if name == ".git" then [ ]
              else
              let
                entryType = entries.${name};
                newRel = if rel == "" then name else rel + "/${name}";
                newPath = dir + "/${name}";
              in
              if entryType == "directory"
              then findAgeFiles newPath newRel
              else if builtins.match ".*\.age$" name != null
              then [ newRel ]
              else [ ]) (builtins.attrNames entries);
          ageFiles = findAgeFiles src "";
          missingRules = builtins.filter (p: ! (builtins.hasAttr p rules)) ageFiles;
          staleRules = builtins.filter (p: ! (builtins.elem p ageFiles)) (builtins.attrNames rules);
        in
        {
          statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            statix check ${self}
            touch $out
          '';
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") (
          {
            # `agenix -c` validates that every secret is encrypted for all
            # recipients in agenix-rules.nix; the Nix-side comparison above
            # additionally catches .age files that have no rule at all (which
            # `agenix -c` cannot see, since it only reads the rules file).
            agenix-secrets = pkgs.runCommand "agenix-secrets-check" {
              nativeBuildInputs = [ agenix.packages.${system}.agenix ];
            } (
              ''
                # agenix evaluates the rules file via nix-instantiate, which
                # needs a writable nix state dir (the sandbox has none).
                export HOME=$(mktemp -d)
                export NIX_STATE_DIR="$HOME/nix/var"
                mkdir -p "$NIX_STATE_DIR"
                cd ${src}
                agenix -c
              ''
              + (
                if missingRules == [ ] && staleRules == [ ] then ''
                  echo "agenix-rules.nix covers all .age files"
                ''
                else
                  ''
                    echo "ERROR: agenix-rules.nix is out of sync with the .age files:"
                  ''
                  + builtins.concatStringsSep "" (map (p: "echo \"  missing rule for: ${p}\"\n") missingRules)
                  + builtins.concatStringsSep "" (map (p: "echo \"  rule for missing file: ${p}\"\n") staleRules)
                  + "exit 1\n"
              )
              + "touch $out\n"
            );
          }
          // nixpkgs.lib.mapAttrs' (
            name: cfg: nixpkgs.lib.nameValuePair "nixos-${name}" cfg.config.system.build.toplevel
          ) nixosConfigurations
        )
      );
      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = nixpkgs.lib.getAttrs [ "x86_64-linux" ] self.checks;
      };
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
                emmberkat.ui.enable = true;
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
              ];
            }
            ./system/catalyst
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            hermes-agent.nixosModules.default
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
                emmberkat.ui.enable = true;
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
