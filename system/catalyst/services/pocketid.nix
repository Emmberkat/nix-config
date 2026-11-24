{ config, ... }:
{
  age.secrets."pocketid/key" = {
    file = ../secrets/pocketid/key.age;
    owner = "pocket-id";
  };

  services = {
    nginx.virtualHosts = {
      "auth.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:1411";
        };
      };
    };

    pocket-id = {
      enable = true;
      settings = {
        APP_URL = "https://auth.emmberkat.com";
        PORT = 1411;
        ENCRYPTION_KEY_FILE = config.age.secrets."pocketid/key".path;
        TRUST_PROXY = true;
        # OpenTelemetry's Prometheus exporter, on localhost:9464 by default.
        OTEL_METRICS_EXPORTER = "prometheus";
      };
    };

    prometheus.scrapeConfigs = [
      {
        job_name = "pocket-id";
        static_configs = [ { targets = [ "127.0.0.1:9464" ]; } ];
      }
    ];
  };

}
