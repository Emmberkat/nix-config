{ pkgs, config, ... }: {

  age.secrets = {
    "nextcloud/adminpass".file = ../secrets/nextcloud/adminpass.age;
    "nextcloud/s3secret".file = ../secrets/nextcloud/s3secret.age;
  };

  services = {

    nginx.virtualHosts = {
      ${config.services.nextcloud.hostName} = {
        enableACME = true;
        forceSSL = true;
      };
    };

    nextcloud = {
      enable = true;
      package = pkgs.nextcloud34;
      hostName = "nextcloud.emmberkat.com";
      config = {
        adminpassFile = config.age.secrets."nextcloud/adminpass".path;
        dbtype = "sqlite";
        objectstore.s3 = {
          enable = true;
          bucket = "nextcloud";
          verify_bucket_exists = true;
          key = "GK265d6dd741412011f662a2c7";
          secretFile = config.age.secrets."nextcloud/s3secret".path;
          hostname = "s3.emmberkat.com";
          useSsl = true;
          port = 443;
          usePathStyle = true;
          region = "sea";
        };
      };
      settings = {
        overwriteprotocol = "https";
        maintenance_window_start = 1;
        default_phone_region = "US";
        log_type = "systemd";
        serverid = 0;
        # Soft auto-provisioning (user_oidc's defaults, pinned here): an OIDC
        # login whose uid matches an existing Nextcloud user signs in as that
        # user; unknown uids get a new account. App passwords (the "hermes"
        # MCP user, desktop/mobile sync) keep working, and so does the
        # password login form (allow_multiple_user_backends defaults to on).
        user_oidc = {
          auto_provision = true;
          soft_auto_provision = true;
        };
      };
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          news
          contacts
          calendar
          tasks
          maps
          spreed
          mail
          cookbook
          user_oidc
          ;
        integration_immich = pkgs.fetchNextcloudApp {
          url = "https://github.com/xXRoxXeRXx/integration_immich/releases/download/v1.3.0/integration_immich.tar.gz";
          hash = "sha256-qj17akAhoXQjIWmBts1a8pinS4usXq5iV5SrVcqrTrQ=";
          license = "agpl3Only";
        };
      };
      extraAppsEnable = true;
    };

  };

  # Pocket ID (pocketid.nix) login provider for user_oidc. It lives only in
  # Nextcloud's DB (user_oidc has no config.php equivalent), so it is created
  # once by hand, not on every boot. Re-run after a fresh DB or to change it:
  #
  #   sudo nextcloud-occ user_oidc:provider pocketid \
  #     --clientid=bf5eae97-a695-4124-a9e5-0492d3267ebc \
  #     --clientsecret=public-client-pkce \
  #     --discoveryuri=https://auth.emmberkat.com/.well-known/openid-configuration \
  #     --scope="openid email profile" \
  #     --unique-uid=0 \
  #     --mapping-uid=preferred_username \
  #     --mapping-display-name=name \
  #     --mapping-email=email
  #
  # The Pocket ID client is Public (PKCE S256, used automatically since the
  # discovery doc advertises it). user_oidc has no public-client mode and
  # always sends a client secret, which Pocket ID ignores for public clients,
  # so the secret above is a fixed non-secret placeholder. Redirect URI on the
  # client: https://nextcloud.emmberkat.com/apps/user_oidc/code

}
