{
  config,
  lib,
  pkgs,
  ...
}:
let
  agentPkg = config.services.hermes-agent.package;

  # The plugin and client live in the same vectorize-io/hindsight monorepo as
  # the server. Build them from the server package's own source, so they move
  # with nixpkgs' hindsight-api-slim (bumped by the flake.lock workflow) and
  # always match the server's API version.
  hindsightSrc = pkgs.hindsight-api-slim.src;

  # Its dependencies all ship in the agent's venv; listing them here would
  # trip the module's collision check.
  hindsightClient = agentPkg.passthru.python.pkgs.buildPythonPackage {
    pname = "hindsight-client";
    inherit (pkgs.hindsight-api-slim) version;
    pyproject = true;
    src = hindsightSrc;
    sourceRoot = "${hindsightSrc.name}/hindsight-clients/python";
    build-system = [ agentPkg.passthru.python.pkgs.hatchling ];
    dontCheckRuntimeDeps = true;
  };

  hindsightPlugin =
    pkgs.runCommandLocal "hindsight" { }
      "cp -r ${hindsightSrc}/hindsight-integrations/hermes $out";
in
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

    # FORGEJO_TOKEN=<git.emmberkat.com PAT: read:repository, write:repository,
    # read:issue; scoped to Muster/kitdata, so it can open PRs there>
    "hermes/forgejo-env" = {
      file = ../secrets/hermes/forgejo-env.age;
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

      skills = {
        external_dirs = [ "${pkgs.field-guide-skill}" ];
        auto_load = [ "field-guide" ];
      };

      # mcpServers has no oauth option. Muster's own public Pocket ID client
      # (PKCE, no secret), since Pocket ID has no dynamic registration; the
      # device flow because catalyst has no browser. The device flow requests
      # only the configured scope (it ignores Muster's scopes_supported), so
      # without it Pocket ID issues a token with no Muster permissions.
      mcp_servers.muster.oauth = {
        client_id = "f4b5eabb-ca92-4187-a0aa-d713073f6e43";
        flow = "device";
        scope = "muster:read muster:write offline_access";
      };

      plugins.enabled = [
        "comfyui"
        "git-review"
      ];
      image_gen.provider = "comfyui";
      # The NixOS module symlinks extraPlugins as nix-managed-<name>, and
      # Hermes uses the directory name as the memory provider id, so the
      # configured name must match the symlink, not the plugin's own name.
      memory.provider = "nix-managed-hindsight";
    };

    extraPlugins = [
      (pkgs.fetchFromGitHub {
        owner = "mister-ideas";
        repo = "git-review";
        rev = "a1944377c3f8d5699668b67379be9bf63ca0cee7";
        hash = "sha256-gO0wovB/OIxMLWLF2KovISyTL+8eA+oKGlsjMfs2rEI=";
      })
      (pkgs.runCommandLocal "comfyui" { } "cp -r ${./hermes-plugins/comfyui} $out")
      hindsightPlugin
    ];

    extraPythonPackages = [ hindsightClient ];

    hermesHomeFiles."hindsight/config.json" = builtins.toJSON {
      mode = "local_external";
      api_url = "http://127.0.0.1:8890";
      bank_id = "hermes";
    };

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
      config.age.secrets."hermes/forgejo-env".path
    ];

    addToSystemPackages = true;
  };

  # nesquena/hermes-webui replaces the built-in dashboard (backend.mode
  # defaults to "none"). It runs the agent in-process with the agent's own
  # venv, as the hermes user so it shares HERMES_HOME/state.db with the
  # messaging gateway.
  services.hermes-webui =
    let
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
        PYTHONPATH = "${hindsightClient}/lib/python${pythonVersion}/site-packages";
      };
    };
}
