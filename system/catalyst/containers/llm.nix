{ pkgs, config, ... }:
let
  openwebuiPort = 8040;
  ollamaPort = 8041;
in
{
  services.traefik.dynamicConfigOptions.http = {
    routers = {
      openwebui = {
        rule = "Host(`llm.emmberkat.com`)";
        entrypoints = "websecure";
        service = "openwebui";
        tls.certresolver = "letsencrypt";
      };
      ollama = {
        rule = "Host(`ollama.emmberkat.com`)";
        entrypoints = "websecure";
        service = "ollama";
        middlewares = [
          "internal"
          "ollama-headers"
        ];
        tls.certresolver = "letsencrypt";
      };
    };
    services.openwebui.loadBalancer.servers = [
      { url = "http://localhost:${toString openwebuiPort}"; }
    ];
    services.ollama.loadBalancer.servers = [ { url = "http://localhost:${toString ollamaPort}"; } ];
    middlewares = {
      ollama-headers = {
        headers = {
          customRequestHeaders = {
            "Host" = "127.0.0.1";
            "Origin" = "";
          };
        };
      };
    };
  };

  services.open-webui = {
    enable = true;
    port = openwebuiPort;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://localhost:${toString ollamaPort}";
    };
  };
  services.ollama = {
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
      "deepseek-r1:1.5b"
      "deepseek-r1:14b"
      "deepseek-r1:7b"
      "deepseek-r1:8b"
      "dolphin-mistral:7b"
      "dolphin-phi:2.7b"
      "gemma3:12b"
      "gemma3:1b"
      "gemma3:27b"
      "gemma3:4b"
      "gemma3n:e4b"
      "gpt-oss:20b"
      "granite4:micro"
      "granite4:micro-h"
      "granite4:tiny-h"
      "llama4:16x17b"
      "llava:7b"
      "minicpm-v:8b"
      "mistral-small3.2:24b"
      "qwen3-vl:4b"
      "qwen3-vl:8b"
      "qwen3.5:4b"
      "qwen3.5:9b"
      "qwen3:14b"
      "qwen3:4b"
      "qwen3:8b"

    ];
  };

}
