{ config, lib, ... }:
let
  secret = name: config.age.secrets."openclaw/${name}".path;

  # Off until https://github.com/openclaw/nix-openclaw/issues/158 is fixed.
  # On 2026.9.4 the Discord plugin calls openKeyedStore while registering, and
  # the runtime only grants that to bundled plugins or verified official
  # installs. A plugin loaded from a Nix store path is neither
  # (reason=record-missing), so it fails to register, and Discord never
  # connects while Telegram carries on. The token secret is kept, so flipping
  # this back on is all a fixed release should need.
  discord = false;
in
{
  # Owned by emmberkat because the gateway runs in their user systemd instance,
  # not as a system service. The wrapper reads each file into the named env var
  # at startup, and the config below refers to them as env SecretRefs, so no
  # token ever lands in the Nix store.
  age.secrets = {
    "openclaw/gateway-token" = {
      file = ../secrets/openclaw/gateway-token.age;
      owner = "emmberkat";
    };
    "openclaw/telegram-bot-token" = {
      file = ../secrets/openclaw/telegram-bot-token.age;
      owner = "emmberkat";
    };
    "openclaw/discord-bot-token" = {
      file = ../secrets/openclaw/discord-bot-token.age;
      owner = "emmberkat";
    };
  };

  users.users.emmberkat.linger = true;

  home-manager.users.emmberkat.systemd.user.services.openclaw-gateway = {
    # The upstream module writes the unit with no [Install] section, so it is
    # only ever linked, never enabled, and nothing starts it -- not the deploy,
    # and not boot either, lingering or no.
    Install.WantedBy = [ "default.target" ];
    # Upstream appends to /tmp/openclaw/openclaw-gateway.log, a directory only
    # created at activation. Once tmpfiles ages it out of /tmp, the append:
    # redirect fails and the unit dies on its next restart.
    Service = {
      StandardOutput = lib.mkForce "journal";
      StandardError = lib.mkForce "journal";
    };
  };

  home-manager.users.emmberkat.programs.openclaw = {
    enable = true;

    environment = {
      OPENCLAW_GATEWAY_TOKEN = secret "gateway-token";
      TELEGRAM_BOT_TOKEN = secret "telegram-bot-token";
      DISCORD_BOT_TOKEN = secret "discord-bot-token";
    };

    runtimePlugins = [ "searxng" ] ++ lib.optional discord "discord";

    config = {
      # LAN-reachable at 10.1.0.1:18789 (see networking.firewall.allowedTCPPorts
      # below). Every connection -- the dashboard included -- still needs the
      # shared OPENCLAW_GATEWAY_TOKEN, so this isn't opening the gateway up
      # wide, just off of localhost/SSH-tunnel-only.
      gateway = {
        mode = "local";
        bind = "lan";
        auth = {
          mode = "token";
          token = {
            source = "env";
            provider = "default";
            id = "OPENCLAW_GATEWAY_TOKEN";
          };
        };
      };

      # DMs default to pairing: an unknown sender gets a code, and nothing
      # reaches the agent until it is approved on catalyst with
      #   openclaw pairing approve <telegram|discord> <CODE>
      channels = {
        telegram = {
          enabled = true;
          # Not tokenFile: that rejects symlinks, and agenix paths go through
          # the /run/agenix -> /run/agenix.d/N generation link.
          botToken = {
            source = "env";
            provider = "default";
            id = "TELEGRAM_BOT_TOKEN";
          };
          dmPolicy = "pairing";
          groupPolicy = "allowlist";
        };
      }
      // lib.optionalAttrs discord {
        discord = {
          enabled = true;
          token = {
            source = "env";
            provider = "default";
            id = "DISCORD_BOT_TOKEN";
          };
          dmPolicy = "pairing";
          groupPolicy = "allowlist";
        };
      };

      # kuzco serves this over the LAN. Its llama-server runs a single slot, so
      # the whole 96K window belongs to whoever is asking; open-webui no longer
      # shares it, since catalyst stopped serving a model of its own.
      models = {
        mode = "merge";
        providers.kuzco = {
          baseUrl = "http://10.1.0.2:8041/v1";
          apiKey = "llama-cpp-local";
          api = "openai-completions";
          models = [
            {
              id = "Qwen3.8-27B-Q4_K_XL";
              name = "Qwen3.8 27B";
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 98304;
              # Matched to the window rather than set below it. OpenClaw derives
              # its prompt budget by subtracting a reserve of one quarter of
              # contextTokens, capped at 20000 once contextTokens reaches 80000.
              # At 73728 the quarter still binds, reserving 18432 and leaving a
              # 55296 prompt budget that compaction kept overshooting -- logged
              # as estimatedPromptTokens=102892 against promptBudgetBeforeReserve
              # =55296, then a one-token answer and reasoning-only retries
              # exhausted. At 98304 the 20000 cap binds instead, so the prompt
              # budget is 78304 and output room is still reserved.
              contextTokens = 98304;
            }
          ];
        };
      };
      agents.defaults.model = {
        primary = "kuzco/Qwen3.8-27B-Q4_K_XL";
      };

      # Every tool schema up front made each turn a ~30K-token prompt, half the
      # context window. That hurts most on a cache miss: this is a hybrid-
      # attention model, so a changed prefix means reprocessing the whole
      # prompt, which took 70s. OpenClaw turns this on by itself for Ollama,
      # LM Studio and managed local servers, but it does not treat a custom
      # provider as local from a loopback URL. The limits match the defaults
      # it uses for those local routes.
      tools.toolSearch = {
        mode = "tools";
        searchDefaultLimit = 5;
        maxSearchLimit = 10;
      };

      # web_search through the SearXNG instance in searx.nix. Unlike Discord,
      # this plugin never touches the trust-gated plugin APIs, so it registers
      # fine when loaded from the Nix store.
      tools.web.search.provider = "searxng";
      plugins.entries.searxng.config.webSearch.baseUrl =
        "http://127.0.0.1:${toString config.services.searx.settings.server.port}";
    };
  };

  # gateway.bind = "lan" above only makes the app itself listen on the LAN
  # interface; the host firewall still blocked it, so nothing outside
  # catalyst could actually reach 18789 (the node connection from crystal
  # included, which retried a timed-out handshake indefinitely).
  networking.firewall.allowedTCPPorts = [ 18789 ];
}
