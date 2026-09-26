{ config, ... }:
let
  openwebuiPort = 8040;
in
{
  # Bearer key for the Hermes OpenAI-compatible API server (hermes.nix,
  # 127.0.0.1:8642) — the same key Hermes itself uses as API_SERVER_KEY.
  # Rendered into the Open WebUI service environment as OPENAI_API_KEY.
  age.secrets."open-webui/api-server-key" = {
    file = ../secrets/open-webui/api-server-key.age;
  };

  services = {
    nginx.virtualHosts."llm.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString openwebuiPort}";
        proxyWebsockets = true;
      };
    };

    # Open WebUI — chat frontend. Backend: the Hermes OpenAI-compatible
    # API server (hermes.nix), so chats here run the full Hermes agent
    # against the same model config as hermes.emmberkat.com.
    # OPENAI_API_BASE_URL is not a secret, so plain `environment`; the
    # bearer key comes from the age secret above.
    open-webui = {
      enable = true;
      port = openwebuiPort;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        # Public URL behind the nginx proxy, so generated links and
        # OAuth redirects point at llm.emmberkat.com, not localhost.
        WEBUI_URL = "https://llm.emmberkat.com";
        # Backend: the Hermes OpenAI-compatible API server (hermes.nix).
        OPENAI_API_BASE_URL = "http://127.0.0.1:8642/v1";
      };
      environmentFile = config.age.secrets."open-webui/api-server-key".path;
    };

  };

}
