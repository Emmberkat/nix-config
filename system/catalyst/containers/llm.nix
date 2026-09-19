_:
let
  openwebuiPort = 8040;
  llamaPort = 8041;
in
{
  services = {
    nginx.virtualHosts = {
      # kuzco serves the model now; catalyst has no llama-cpp of its own. The
      # allow list already covers kuzco, which sits on the same /8.
      "llama.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://10.1.0.2:${toString llamaPort}";
          proxyWebsockets = true;
          extraConfig = ''
            allow 127.0.0.1/32;
            allow 10.0.0.0/8;
            deny all;
          '';
        };
      };
    };

    open-webui = {
      enable = true;
      port = openwebuiPort;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
      };
    };

  };

}
