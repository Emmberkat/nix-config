{ pkgs, config, lib, ... }:
let
  # Pocket ID (pocketid.nix) OIDC client, set to Public: PKCE (S256, which
  # user_oidc uses whenever the discovery doc advertises it) proves each code
  # exchange. Redirect URI registered on the client:
  #   https://nextcloud.emmberkat.com/apps/user_oidc/code
  oidcClientId = "bf5eae97-a695-4124-a9e5-0492d3267ebc";
in
{

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

  # Register/refresh the Pocket ID provider. `user_oidc:provider` is an upsert
  # keyed on the identifier, so this is idempotent and re-runs whenever the
  # client ID changes. The provider lives in Nextcloud's DB.
  #
  # user_oidc has no public-client mode: it always sends a client secret to
  # the token endpoint. Pocket ID ignores the secret for public clients, so a
  # fixed non-secret placeholder is stored instead of a real one.
  systemd.services.nextcloud-oidc-provider = {
    description = "Configure Pocket ID login for Nextcloud";
    wantedBy = [ "multi-user.target" ];
    after = [ "nextcloud-setup.service" ];
    requires = [ "nextcloud-setup.service" ];
    restartTriggers = [ oidcClientId ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "nextcloud";
      # Same runtime credentials the module gives its own occ units: the S3
      # secret is needed to boot Nextcloud at all.
      inherit (config.systemd.services.nextcloud-update-db.serviceConfig) LoadCredential;
    };
    script = ''
      ${lib.getExe config.services.nextcloud.occ} user_oidc:provider pocketid \
        --clientid=${lib.escapeShellArg oidcClientId} \
        --clientsecret=public-client-pkce \
        --discoveryuri=https://auth.emmberkat.com/.well-known/openid-configuration \
        --scope="openid email profile" \
        --unique-uid=0 \
        --mapping-uid=preferred_username \
        --mapping-display-name=name \
        --mapping-email=email
    '';
  };

}
