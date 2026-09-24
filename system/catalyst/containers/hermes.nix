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

  services.hermes-agent = {
    enable = true;

    settings = {
      model = {
        provider = "custom";
        base_url = "http://10.1.0.2:8041/v1";
        api_key = "llama-cpp-local";
        default = "Qwen3.8-27B-Q4_K_XL";
      };

      # Pin web_search to the SearXNG instance in searx.nix. Without this
      # Hermes rotates through the keyless public free tiers instead, which
      # rate-limit and leak the query off-network.
      web.search_backend = "searxng";
    };

    # Not a secret, so plain `environment` rather than environmentFiles: this
    # is how Hermes discovers a self-hosted SearXNG.
    environment.SEARXNG_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}";

    # LAN-reachable at 10.1.0.1:9119 (see networking.firewall.allowedTCPPorts
    # below). Binding off loopback makes the module turn on its own auth
    # gate automatically; sessionTokenFile pins that to a stable secret
    # instead of a fresh throwaway token on every restart, and it also
    # doubles as the token Hermes Desktop needs to reach this backend.
    backend = {
      mode = "dashboard";
      host = "10.1.0.1";
      sessionTokenFile = config.age.secrets."hermes/dashboard-token".path;
    };

    # Puts the `hermes` CLI on the system PATH and exports HERMES_HOME
    # system-wide, so an interactive `hermes` shares sessions, skills and
    # memory with the gateway service instead of a private ~/.hermes.
    addToSystemPackages = true;
  };

  networking.firewall.allowedTCPPorts = [ 9119 ];
}
