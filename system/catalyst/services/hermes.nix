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

    # NEXTCLOUD_PASSWORD=<app password of the "hermes" Nextcloud user>
    "hermes/nextcloud-env" = {
      file = ../secrets/hermes/nextcloud-env.age;
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

      # Notes, calendar/tasks, contacts, files, cookbook, news, mail, ... as
      # the dedicated "hermes" Nextcloud user. The app password is resolved
      # from $HERMES_HOME/.env (hermes/nextcloud-env) when the server is
      # spawned, so only the placeholder reaches the store.
      nextcloud = {
        command = lib.getExe pkgs.nextcloud-mcp-server;
        args = [
          "run"
          "--transport"
          "stdio"
        ];
        env = {
          NEXTCLOUD_HOST = "https://${config.services.nextcloud.hostName}";
          NEXTCLOUD_USERNAME = "emmberkat";
          NEXTCLOUD_PASSWORD = "\${NEXTCLOUD_PASSWORD}";
        };
      };

      # Self-hosted 40K collection tracker, MCP over HTTP. Muster takes Pocket
      # ID access tokens for its API (resource https://muster.emmberkat.com,
      # scopes muster:read/muster:write) and says where to sign in (RFC 9728),
      # so the URL is the public one: the token's resource must match it.
      # Sign in once with `hermes mcp login muster` (device code); the tokens
      # live in $HERMES_HOME/mcp-tokens/, outside the store, and survive deploys.
      muster = {
        url = "https://muster.emmberkat.com/mcp";
        auth = "oauth";
        timeout = 120;
        connect_timeout = 30;
      };
    };

    settings = {
      model = {
        provider = "custom";
        base_url = "http://10.1.0.2:8041/v1";
        api_key = "llama-cpp-local";
        default = "Qwen3.8-27B";
      };

      web.search_backend = "searxng";

      # mcpServers has no oauth option. Muster's own public Pocket ID client
      # (PKCE, no secret), since Pocket ID has no dynamic registration; the
      # device flow because catalyst has no browser.
      mcp_servers.muster.oauth = {
        client_id = "f4b5eabb-ca92-4187-a0aa-d713073f6e43";
        flow = "device";
      };

      plugins.enabled = [ "comfyui" ];
      image_gen.provider = "comfyui";
    };

    extraPlugins = [
      (pkgs.runCommandLocal "comfyui" { } "cp -r ${./hermes-plugins/comfyui} $out")
    ];

    environment = {
      COMFYUI_URL = "http://127.0.0.1:${toString config.services.comfyui.port}";
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
      config.age.secrets."hermes/nextcloud-env".path
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
