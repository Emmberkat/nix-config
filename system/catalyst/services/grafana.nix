{ config, ... }:
let
  grafHost = "grafana.emmberkat.com";
in
{
  services = {
    grafana = {
      enable = true;
      settings = {
        server = {
          # Served by the vhost below, so the port stays on loopback.
          http_addr = "127.0.0.1";
          http_port = 3000;
          root_url = "https://${grafHost}/";
        };
        # Login is handled by oauth2-proxy (Pocket ID) in front of nginx;
        # Grafana trusts the X-User header it passes through.
        "auth.anonymous".enabled = false;
        "auth.proxy" = {
          enabled = true;
          auto_sign_in = true;
          header_name = "X-User";
          org_name = "Main Org.";
        };
        security = {
          # Grafana's file provider: the value is read from the file at
          # startup, so the key itself never lands in the world-readable
          # Nix store.
          secret_key =
            "$__file" + "{" + config.age.secrets."grafana/secret-key".path + "}";
        };
      };
      provision = {
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              # The provisioned dashboards select their datasource by the
              # name "prometheus" via a template variable.
              name = "prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:9090";
              isDefault = true;
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "default";
              type = "file";
              options.path = ../grafana/dashboards;
            }
          ];
        };
      };
    };

    # Joins comfy and prometheus behind the existing oauth2-proxy (Pocket
    # ID client from comfyui.nix); the session cookie is shared across
    # *.emmberkat.com.
    oauth2-proxy.nginx.virtualHosts.${grafHost} = { };
  };

  services.nginx.virtualHosts.${grafHost} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true;
    };
  };

  age.secrets."grafana/secret-key".file = ../secrets/grafana/secret-key.age;
}
