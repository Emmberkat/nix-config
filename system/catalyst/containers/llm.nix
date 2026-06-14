{ pkgs, config, ... }:
let
  openwebuiPort = 8040;
  ollamaPort = 8041;
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
      "ollama.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString ollamaPort}";
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
        OLLAMA_API_BASE_URL = "http://localhost:${toString ollamaPort}";
      };
    };

    ollama = {
      enable = true;
      port = ollamaPort;
      user = "ollama";
      home = "/mnt/ollama";
      package = pkgs.ollama-cuda;
      openFirewall = true;
      environmentVariables = {
        OLLAMA_ORIGINS = "*";
      };
      loadModels = [
        "qwen3.5:4b"
        "qwen3.5:9b"
      ];
    };
  };

}
