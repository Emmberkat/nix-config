{ config, pkgs, ... }:
let
  port = 9120;
  home = "/var/lib/hermes-work";
  hermesHome = "${home}/.hermes";
in
{
  users = {
    groups.hermes-work = { };
    users.hermes-work = {
      isSystemUser = true;
      group = "hermes-work";
      inherit home;
      createHome = true;
      linger = true;
      autoSubUidGidRange = true;
    };
  };

  age.secrets."hermes-work/claude-oauth-token" = {
    file = ../secrets/hermes/claude-oauth-token.age;
    owner = "hermes-work";
  };

  # The local terminal backend snapshots a login shell, where the home
  # instance's system-wide HERMES_HOME would otherwise win.
  environment.extraInit = ''
    if [ "$(id -un)" = hermes-work ]; then export HERMES_HOME=${hermesHome}; fi
  '';

  home-manager.users.hermes-work.services.hermes-agent = {
    enable = true;
    gateway.enable = true;
    inherit hermesHome;
    workingDirectory = "${home}/workspace";
    backend = {
      mode = "dashboard";
      inherit port;
    };

    extraPackages = with pkgs; [
      config.virtualisation.podman.package
      curl
      diffutils
      findutils
      gawk
      gh
      gnugrep
      gnused
      gnutar
      gzip
      jq
      unzip
      which
    ];

    settings = {
      model = {
        provider = "anthropic";
        default = "claude-opus-5-5";
      };
      agent.reasoning_effort = "medium";
      approvals.mode = "off";
      web.search_backend = "searxng";
      telemetry.shared_metrics = {
        enabled = false;
        send = false;
      };

      terminal = {
        # Set explicitly: the config merge never removes keys from disk.
        backend = "local";
        home_mode = "profile";
      };

      dashboard = {
        public_url = "https://work.hermes.emmberkat.com";
        oauth.self_hosted = {
          issuer = "https://auth.emmberkat.com";
          client_id = "c559cf36-52c3-46d1-bd47-880eede524a5";
        };
      };
    };

    environment = {
      COMFYUI_URL = "http://127.0.0.1:${toString config.services.comfyui.port}";
      SEARXNG_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}";
    };
    environmentFiles = [ config.age.secrets."hermes-work/claude-oauth-token".path ];
  };

  services.nginx.virtualHosts."work.hermes.emmberkat.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
}
