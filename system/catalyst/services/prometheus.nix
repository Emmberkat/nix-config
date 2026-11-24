let
  promHost = "prometheus.emmberkat.com";
in
{
  services = {
    prometheus = {
      enable = true;
      # The UI is served by the vhost below, so the port stays on loopback.
      listenAddress = "127.0.0.1";
      webExternalUrl = "https://${promHost}/";
      # 15s instead of the default 1m so fan and temperature changes during
      # GPU load stay visible.
      globalConfig.scrape_interval = "15s";
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            { targets = [ "127.0.0.1:9100" "10.1.0.2:9100" ]; }
          ];
        }
        {
          job_name = "smartctl";
          static_configs = [
            { targets = [ "127.0.0.1:9633" "10.1.0.2:9633" ]; }
          ];
        }
        {
          job_name = "nvidia-gpu";
          static_configs = [
            { targets = [ "127.0.0.1:9835" ]; }
          ];
        }
        {
          job_name = "oauth2-proxy";
          static_configs = [ { targets = [ "127.0.0.1:4181" ]; } ];
        }
        {
          job_name = "llama-server";
          static_configs = [
            { targets = [ "10.1.0.2:8041" ]; }
          ];
        }
      ];
    };

    # Prometheus has no auth of its own, so it joins the existing oauth2-proxy
    # (configured in comfyui.nix, Pocket ID client) as a second protected
    # vhost. The session cookie is shared across *.emmberkat.com so one
    # Pocket ID login covers both apps; the /oauth2/ callback stays on the
    # comfy emmberkat vhost that owns the client's registered redirect URL.
    oauth2-proxy = {
      cookie.domain = ".emmberkat.com";
      nginx.virtualHosts.${promHost} = { };
      extraConfig.metrics-address = "127.0.0.1:4181";
    };
  };

  services.nginx.virtualHosts.${promHost} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:9090";
      proxyWebsockets = true;
    };
  };

  systemd.services.oauth2-proxy = {
    # OIDC discovery goes through nginx to Pocket ID and fails until both are up.
    after = [ "nginx.service" "pocket-id.service" ];
    serviceConfig.RestartSec = "5s";
  };
}
