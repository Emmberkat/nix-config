{ config, ... }:
{
  # Runner registered once in Forgejo's org settings; the token must have no
  # trailing newline (the runner reads it verbatim).
  age.secrets."forgejo-runner/token".file = ../secrets/forgejo-runner/token.age;

  services = {
    forgejo = {
      enable = true;
      settings = {
        server = {
          DOMAIN = "git.emmberkat.com";
          ROOT_URL = "https://git.emmberkat.com/";
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = 3000;
        };
        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = true;
        };
        # Still lets OIDC logins create accounts while local sign-up is off.
        oauth2_client = {
          ENABLE_AUTO_REGISTRATION = true;
          USERNAME = "nickname";
          OPENID_CONNECT_SCOPES = "profile email";
        };
        session.COOKIE_SECURE = true;
      };
    };

    forgejo-runner.instances.catalyst = {
      enable = true;
      settings = {
        runner.labels = [ "python:docker://docker.io/library/python:3.13-bookworm" ];
        container.force_pull = true;
        server.connections.default = {
          url = config.services.forgejo.settings.server.ROOT_URL;
          uuid = "7775e46d-f10d-4fc2-a400-b5b1c60820a6";
        };
      };
      secrets.server.connections.default.token_url = config.age.secrets."forgejo-runner/token".path;
    };

    nginx.virtualHosts."git.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:3000";
    };
  };

  # Rootful until the runner module supports rootless Podman (its TODO).
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
  };
}
