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
    acceleration = "cuda";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_ORIGINS = "*";
    };
    loadModels = [
      "gemma3:1b"
      "deepseek-r1:1.5b"
      "deepseek-r1:7b"
      "deepseek-r1:8b"
      "deepseek-r1:14b"
      "gpt-oss:20b"
      "gemma3:4b"
      "gemma3:12b"
      "gemma3:27b"
      "llava:7b"
      "minicpm-v:8b"
      "mistral-small3.2:24b"
      "qwen3:4b"
      "qwen3:8b"
      "qwen3:14b"
      "granite4:micro"
      "granite4:micro-h"
      "granite4:tiny-h"
      "gemma3n:e4b"
      "llama4:16x17b"
      "llama2-uncensored:7b"
      "dolphin-phi:2.7b"
      "dolphin-mistral:7b"
      "wizard-vicuna-uncensored:7b"
      "wizard-vicuna-uncensored:13b"
      "artifish/llama3.2-uncensored:latest"
      "second_constantine/gpt-oss-u:20b"
      "hf.co/openbmb/MiniCPM-o-2_6-gguf"
      "hf.co/unsloth/Qwen2.5-Omni-7B-GGUF"
      "hf.co/unsloth/Qwen2.5-Omni-3B-GGUF"
    ];
  };

}
