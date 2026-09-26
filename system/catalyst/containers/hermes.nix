{ config, lib, ... }:
{
  # Self-hosted Hermes Agent (Nous Research) — the open-source agent behind
  # the managed "Hermes Cloud" service. Native mode: a hardened systemd
  # service under a dedicated `hermes` user, no container runtime needed.
  #
  # Model: kuzco's llama-cpp server over the LAN. It serves a single slot, so
  # the whole window belongs to whoever is asking. "llama-cpp-local" is a
  # placeholder, not a secret, so it is safe in the Nix store.
  age.secrets."hermes/dashboard-token" = {
    file = ../secrets/hermes/dashboard-token.age;
    owner = "hermes";
  };

  # Claude subscription OAuth token (sk-ant-oat01…, from `claude setup-token`).
  # Rendered into $HERMES_HOME/.env as CLAUDE_CODE_OAUTH_TOKEN, which
  # authenticates the "anthropic" provider for on-demand /model switches.
  age.secrets."hermes/claude-oauth-token" = {
    file = ../secrets/hermes/claude-oauth-token.age;
    owner = "hermes";
  };

  # Bearer key for the OpenAI-compatible API server (port 8642), which Open
  # WebUI (llm.nix) connects to as its backend. Rendered into $HERMES_HOME/.env
  # as API_SERVER_KEY via environmentFiles.
  age.secrets."hermes/api-server-key" = {
    file = ../secrets/hermes/api-server-key.age;
    owner = "hermes";
  };

  services = {
    nginx.virtualHosts = {
      "hermes.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:9119";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.hermes-agent = {
    enable = true;

    settings = {
      model = {
        provider = "custom";
        base_url = "http://10.1.0.2:8041/v1";
        api_key = "llama-cpp-local";
        default = "Qwen3.8-27B-Q4_K_XL";
      };

      # The Claude subscription OAuth token (from the age secret, rendered
      # into $HERMES_HOME/.env via environmentFiles) authenticates the
      # "anthropic" provider. It is NOT a fallback — it's an on-demand
      # option: switch a session to a Claude model with /model
      # (e.g. /model claude-opus-4-6), or pin subagents/cron jobs to one
      # via delegation.model / per-job model settings.

      # Pin web_search to the SearXNG instance in searx.nix. Without this
      # Hermes rotates through the keyless public free tiers instead, which
      # rate-limit and leak the query off-network.
      web.search_backend = "searxng";
    };

    # Not a secret, so plain `environment` rather than environmentFiles:
    # SEARXNG_URL is how Hermes discovers a self-hosted SearXNG, and the
    # API_SERVER_* vars enable the OpenAI-compatible API server that Open
    # WebUI (llm.nix) connects to. The API server is loopback-only — same
    # host as Open WebUI, so no firewall port and no LAN exposure. Its
    # bearer key comes from the age secret below.
    environment = {
      SEARXNG_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}";
      HERMES_DASHBOARD_AUTH_PROVIDER = "self-hosted";
      HERMES_DASHBOARD_OIDC_ISSUER = "https://auth.emmberkat.com";
      HERMES_DASHBOARD_OIDC_CLIENT_ID = "4a326920-c869-423c-bbd6-e201a99e4f8b";
      HERMES_DASHBOARD_PUBLIC_URL = "https://hermes.emmberkat.com";
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "127.0.0.1";
      API_SERVER_PORT = "8642";
    };

    # Appended to $HERMES_HOME/.env on every activation. The claude secret
    # holds `CLAUDE_CODE_OAUTH_TOKEN=<token>` — the credential for the
    # anthropic provider (see the comment in the hermes config above); the
    # api-server secret holds `API_SERVER_KEY=<key>` — the bearer token for
    # the OpenAI-compatible API server.
    environmentFiles = [
      config.age.secrets."hermes/claude-oauth-token".path
      config.age.secrets."hermes/api-server-key".path
    ];
    # LAN-reachable at 10.1.0.1:9119 (see networking.firewall.allowedTCPPorts
    # below). Binding off loopback makes the module turn on its own auth
    # gate automatically; sessionTokenFile pins that to a stable secret
    # instead of a fresh throwaway token on every restart, and it also
    # doubles as the token Hermes Desktop needs to reach this backend.
    backend = {
      mode = "dashboard";
      port = 9119;
      sessionTokenFile = config.age.secrets."hermes/dashboard-token".path;
    };

    # Puts the `hermes` CLI on the system PATH and exports HERMES_HOME
    # system-wide, so an interactive `hermes` shares sessions, skills and
    # memory with the gateway service instead of a private ~/.hermes.
    addToSystemPackages = true;
  };

  networking.firewall.allowedTCPPorts = [ 9119 ];
}
