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
        dashboard = {
          public_url = "https://${domain}";
          oauth.self_hosted = {
            issuer = "https://auth.emmberkat.com";
            client_id = clientId;
          };
        };
      };

      environment = {
        COMFYUI_URL = "http://127.0.0.1:${toString config.services.comfyui.port}";
        SEARXNG_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}";
      };
    };
  };
}
