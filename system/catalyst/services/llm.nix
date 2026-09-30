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

        # Pocket ID login. Redirect URI registered on the Pocket ID client:
        #   https://llm.emmberkat.com/oauth/oidc/callback
        OPENID_PROVIDER_URL = "https://auth.emmberkat.com/.well-known/openid-configuration";
        OPENID_REDIRECT_URI = "https://llm.emmberkat.com/oauth/oidc/callback";
        OAUTH_CLIENT_ID = "b4c26551-590a-49ab-9df3-5d5da8c983b0";
        # Public client (no secret): PKCE proves each code exchange instead,
        # and "none" sends client_id in the body rather than an empty
        # Basic-auth secret. Open WebUI only registers the provider when a
        # secret or a code challenge method is set.
        OAUTH_CODE_CHALLENGE_METHOD = "S256";
        OAUTH_TOKEN_ENDPOINT_AUTH_METHOD = "none";
        OAUTH_PROVIDER_NAME = "Pocket ID";
        OAUTH_SCOPES = "openid email profile";
        # Password signup stays closed (enable_signup=false in the live
        # config); OIDC users are created on first login, and an existing
        # local account with the same email is linked rather than duplicated.
        ENABLE_OAUTH_SIGNUP = "True";
        OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
        # The env here, not the admin-panel copy in the DB, is authoritative.
        ENABLE_OAUTH_PERSISTENT_CONFIG = "False";
        # Password form kept as a fallback while auth.emmberkat.com is the
        # only IdP; flip to False once OIDC login is proven.
        ENABLE_LOGIN_FORM = "True";
      };
      environmentFile = config.age.secrets."open-webui/api-server-key".path;
    };

  };

}
