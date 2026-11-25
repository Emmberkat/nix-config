# What every Hermes instance on catalyst gets: its own system user with state
# in /var/lib/<user>, the gateway, and a dashboard behind its own vhost and
# Pocket ID client. Each instance file adds only what is its own.
{
  user,
  port,
  domain,
  clientId,
}:
{ config, pkgs, ... }:
let
  agentPkg = config.home-manager.users.${user}.services.hermes-agent.package;

  # The plugin and client live in the same vectorize-io/hindsight monorepo as
  # the server. Build them from the server package's own source, so they move
  # with nixpkgs' hindsight-api-slim (bumped by the flake.lock workflow) and
  # always match the server's API version.
  hindsightSrc = pkgs.hindsight-api-slim.src;

  # Its dependencies all ship in the agent's venv; listing them here would
  # trip the module's collision check.
  hindsightClient = agentPkg.passthru.python.pkgs.buildPythonPackage {
    pname = "hindsight-client";
    inherit (pkgs.hindsight-api-slim) version;
    pyproject = true;
    src = hindsightSrc;
    sourceRoot = "${hindsightSrc.name}/hindsight-clients/python";
    build-system = [ agentPkg.passthru.python.pkgs.hatchling ];
    dontCheckRuntimeDeps = true;
  };

  hindsightPlugin =
    pkgs.runCommandLocal "hindsight" { }
      "cp -r ${hindsightSrc}/hindsight-integrations/hermes $out";
in
{
  users = {
    groups.${user} = { };
    users.${user} = {
      isSystemUser = true;
      group = user;
      home = "/var/lib/${user}";
      createHome = true;
      linger = true;
      shell = pkgs.zsh;
      autoSubUidGidRange = true;
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };

  home-manager.users.${user} = {
    imports = [ ../../../../modules/zsh.nix ];

    services.hermes-agent = {
      enable = true;
      gateway.enable = true;
      hermesHome = "/var/lib/${user}/.hermes";
      workingDirectory = "/var/lib/${user}/workspace";
      backend = {
        mode = "dashboard";
        inherit port;
      };

      # systemd-run: the gateway runs Kanban workers in their own user scope
      # and refuses to spawn them when it is not on PATH.
      extraPackages = [
        config.virtualisation.podman.package
        config.systemd.package
      ];

      settings = {
        web.search_backend = "searxng";
        toolsets = [ "kanban" ];
        security.protected_instruction_files = false;
        # The module symlinks extraPlugins as nix-managed-<name>, and
        # Hermes uses the directory name as the memory provider id, so the
        # configured name must match the symlink, not the plugin's own name.
        memory.provider = "nix-managed-hindsight";
        dashboard = {
          public_url = "https://${domain}";
          oauth.self_hosted = {
            issuer = "https://auth.emmberkat.com";
            client_id = clientId;
          };
        };
      };

      extraPlugins = [ hindsightPlugin ];
      extraPythonPackages = [ hindsightClient ];

      # One shared server; each instance keeps its memories in its own bank.
      hermesHomeFiles."hindsight/config.json" = builtins.toJSON {
        mode = "local_external";
        api_url = "http://127.0.0.1:8890";
        bank_id = user;
      };

      environment = {
        COMFYUI_URL = "http://127.0.0.1:${toString config.services.comfyui.port}";
        SEARXNG_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}";
      };
    };
  };
}
