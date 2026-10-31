# Forgejo — self-hosted git forge (community fork of Gitea), AGPL.
#
# Login is via Pocket ID (OIDC) only: registration is disabled and sign-in is
# required, so the only way in is the "Pocket ID" OpenID Connect source.
#
# OIDC source (one-off, after first deploy — Forgejo keeps external auth
# sources in its DB, not app.ini, so this can't be declarative):
#   1. Create an admin to log in with:
#        sudo -u forgejo forgejo --work-path /var/lib/forgejo admin user create \
#          --admin --username <name> --email <email> --random-password
#   2. Pocket ID → OIDC Clients → add "Forgejo", *not* public (Forgejo's goth
#      OIDC client sends a client secret and has no PKCE), callback
#      https://git.emmberkat.com/user/oauth2/Pocket%20ID/callback
#   3. Forgejo Site Administration → Authentication Sources → Add:
#        Type: OAuth2, Provider: OpenID Connect, Name: Pocket ID
#        Client ID / Secret: from step 2 (stored in Forgejo's DB, so no
#        agenix file — nothing on the host would read it)
#        Auto Discovery URL: https://auth.emmberkat.com/.well-known/openid-configuration
_: {
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

    nginx.virtualHosts."git.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:3000";
    };
  };
}
