{ pkgs, config, ... }:
let
  openwebuiPort = 8040;
  llamaPort = 8041;
in
{
  services = {
    nginx.virtualHosts = {
      "llm.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString openwebuiPort}";
          proxyWebsockets = true;
        };
      };
      "llama.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString llamaPort}";
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

    llama-cpp = {
      enable = true;
      package = pkgs.pkgsCuda.llama-cpp;
      settings = {
        models-max = 1;
        fit = "on";
        ctx-size = 0;
        port = llamaPort;
        models-dir = "/mnt/models";
      };
    };
  };

}
