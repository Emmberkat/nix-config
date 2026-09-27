{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Native Kiro model provider (AWS Builder ID / IAM Identity Center login).
  # Catalog entry `kiro-provider`; the plugin lives in the repo's provider/ subdir.
  kiro-provider =
    let
      src = pkgs.fetchFromGitHub {
        owner = "anpicasso";
        repo = "hermes-kiro-provider";
        rev = "013017d27acd58051c4ad654bb21036d93bdd3ce"; # v1.0.1
        hash = "sha256-OwZTt8uSTr9zEAvUT/gToDXWbCaeA9t5Rk9uQLEuk2g=";
      };
    in
    pkgs.runCommand "kiro-provider" { } "cp -r ${src}/provider $out";
in
{
  age.secrets = {
    "hermes/dashboard-token" = {
      file = ../secrets/hermes/dashboard-token.age;
      owner = "hermes";
    };

    "hermes/messaging-env" = {
      file = ../secrets/hermes/messaging-env.age;
      owner = "hermes";
    };

    "hermes/mcp" = {
      file = ../secrets/hermes/mcp.age;
      owner = "hermes";
    };

    "hermes/claude-oauth-token" = {
      file = ../secrets/hermes/claude-oauth-token.age;
      owner = "hermes";
    };

    "hermes/api-server-key" = {
      file = ../secrets/hermes/api-server-key.age;
      owner = "hermes";
    };
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

    extraPlugins = [ kiro-provider ];

    mcpServers = {
      github = {
        command = "npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-github"
        ];
      };
    };

    settings = {
      model = {
        provider = "custom";
        base_url = "http://10.1.0.2:8041/v1";
        api_key = "llama-cpp-local";
        default = "Qwen3.8-27B-Q4_K_XL";
      };

      web.search_backend = "searxng";
    };

    environment = {
      SEARXNG_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}";
      TELEGRAM_ALLOWED_USERS = "1629004256";
      DISCORD_ALLOWED_USERS = "288503618250735616";
      HERMES_DASHBOARD_AUTH_PROVIDER = "self-hosted";
      HERMES_DASHBOARD_OIDC_ISSUER = "https://auth.emmberkat.com";
      HERMES_DASHBOARD_OIDC_CLIENT_ID = "4a326920-c869-423c-bbd6-e201a99e4f8b";
      HERMES_DASHBOARD_PUBLIC_URL = "https://hermes.emmberkat.com";
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "127.0.0.1";
      API_SERVER_PORT = "8642";
    };

    environmentFiles = [
      config.age.secrets."hermes/mcp".path
      config.age.secrets."hermes/messaging-env".path
      config.age.secrets."hermes/claude-oauth-token".path
      config.age.secrets."hermes/api-server-key".path
    ];

    backend = {
      mode = "dashboard";
      port = 9119;
      sessionTokenFile = config.age.secrets."hermes/dashboard-token".path;
    };

    addToSystemPackages = true;
  };

  networking.firewall.allowedTCPPorts = [ 9119 ];
}
