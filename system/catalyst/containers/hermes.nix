{
  config,
  lib,
  pkgs,
  ...
}:
{
  age.secrets = {
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

    # ARTIFACT_RELAY_API_TOKEN: the same value as ARTIFACT_API_TOKEN in
    # artifact-relay/environment -- rotate both together.
    "hermes/artifact-relay-env" = {
      file = ../secrets/hermes/artifact-relay-env.age;
      owner = "hermes";
    };
  };

  services = {
    nginx.virtualHosts = {
      "hermes.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.hermes-webui.port}";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.hermes-agent = {
    enable = true;

    mcpServers = {
      github = {
        command = "npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-github"
        ];
      };
    };

    # Publishes long results as private links on the self-hosted relay
    # (artifact-relay.nix). Pinned to the commit reviewed for the plugin catalog.
    extraPlugins = [
      (pkgs.fetchFromGitHub {
        owner = "eloktev";
        repo = "hermes-artifact-relay";
        name = "artifact-relay";
        rev = "c91fa9229121dd616a275a45447301eacca45e6f";
        hash = "sha256-IafH8ROMIdkddoC4Zqguc7JLncR44m+Hg7Hl2vpJ8rc=";
      })
    ];

    settings = {
      model = {
        provider = "custom";
        base_url = "http://10.1.0.2:8041/v1";
        api_key = "llama-cpp-local";
        default = "Qwen3.8-27B-Q4_K_XL";
      };

      web.search_backend = "searxng";

      plugins = {
        enabled = [ "artifact-relay" ];
        entries.artifact-relay.settings.base_url = "https://artifacts.emmberkat.com";
      };
    };

    environment = {
      SEARXNG_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}";
      TELEGRAM_ALLOWED_USERS = "1629004256";
      DISCORD_ALLOWED_USERS = "288503618250735616";
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "127.0.0.1";
      API_SERVER_PORT = "8642";
    };

    environmentFiles = [
      config.age.secrets."hermes/mcp".path
      config.age.secrets."hermes/messaging-env".path
      config.age.secrets."hermes/claude-oauth-token".path
      config.age.secrets."hermes/api-server-key".path
      config.age.secrets."hermes/artifact-relay-env".path
    ];

    addToSystemPackages = true;
  };

  # nesquena/hermes-webui replaces the built-in dashboard (backend.mode
  # defaults to "none"). It runs the agent in-process with the agent's own
  # venv, as the hermes user so it shares HERMES_HOME/state.db with the
  # messaging gateway.
  services.hermes-webui =
    let
      agentPkg = config.services.hermes-agent.package;
      inherit (agentPkg.passthru.python) pythonVersion;
    in
    {
      enable = true;
      agent = {
        package = agentPkg;
        dir = "${agentPkg.passthru.hermesVenv}/lib/python${pythonVersion}/site-packages";
      };
      user = "hermes";
      group = "hermes";
      hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
      port = 9119;
      extraEnvironment = {
        HERMES_WEBUI_OIDC_ISSUER = "https://auth.emmberkat.com";
        HERMES_WEBUI_OIDC_CLIENT_ID = "4a326920-c869-423c-bbd6-e201a99e4f8b";
        HERMES_WEBUI_OIDC_ALLOW_CLAIM = "email";
        HERMES_WEBUI_OIDC_ALLOW_VALUES = "emmabenkart@gmail.com";
        HERMES_WEBUI_OIDC_REDIRECT_URI = "https://hermes.emmberkat.com/api/auth/oidc/callback";
        HERMES_WEBUI_SECURE = "1";
      };
    };
}
