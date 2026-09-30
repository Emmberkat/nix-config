{ config, pkgs, ... }:
{
  services.nginx.virtualHosts = {
    "photos.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.services.immich.port}";
        proxyWebsockets = true;
      };
    };
  };

  services.immich = {
    enable = true;
    port = 2283;
    mediaLocation = "/mnt/immich";

    # Setting this makes Immich read /run/immich/config.json and locks the
    # admin "System Settings" page: anything not set here falls back to
    # Immich's defaults, not to what was previously saved in the web UI.
    settings = {
      server.externalDomain = "https://photos.emmberkat.com";

      # Pocket ID login. Redirect URIs registered on the Pocket ID client:
      #   https://photos.emmberkat.com/auth/login
      #   https://photos.emmberkat.com/user-settings
      #   app.immich:///oauth-callback   (mobile app)
      # Password login stays on as a fallback for when auth.emmberkat.com is
      # down, and for the existing admin account.
      oauth = {
        enabled = true;
        issuerUrl = "https://auth.emmberkat.com";
        # Public client: no secret. With clientSecret left at its "" default
        # Immich authenticates to the token endpoint with "none", and uses
        # PKCE (S256) because Pocket ID advertises it in its discovery doc.
        clientId = "301e6638-6ba8-4229-a9f6-f6752191ce36";
        scope = "openid email profile";
        buttonText = "Login with Pocket ID";
        # Existing Immich users are linked by matching email on first login.
        autoRegister = true;
        autoLaunch = false;
      };
      passwordLogin.enabled = true;
    };
  };

}
