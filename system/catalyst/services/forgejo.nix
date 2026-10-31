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
