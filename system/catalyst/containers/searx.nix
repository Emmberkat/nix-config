{ config, ... }:
{
  age.secrets."searx/environment".file = ../secrets/searx/environment.age;

  # A private meta-search backend for OpenClaw's web_search tool. Without a
  # search provider the agent can only guess URLs, and it guessed domains that
  # do not exist.
  #
  # Loopback only and not proxied: this is an API for local consumers, not a
  # public instance, which is also why the limiter (and the valkey it needs) is
  # off -- it exists to fend off bots hitting a public instance.
  services.searx = {
    enable = true;
    environmentFile = config.age.secrets."searx/environment".path;
    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        secret_key = "$SEARX_SECRET_KEY";
        limiter = false;
        public_instance = false;
      };
      # OpenClaw's provider queries format=json, which SearXNG rejects with a
      # 403 unless json is listed here.
      search.formats = [
        "html"
        "json"
      ];
    };
  };
}
