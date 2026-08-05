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
      config.adminpassFile = config.age.secrets."nextcloud/adminpass".path;
      config.dbtype = "sqlite";
      config.objectstore.s3 = {
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
      settings = {
        overwriteprotocol = "https";
        maintenance_window_start = 1;
        default_phone_region = "US";
        log_type = "systemd";
        serverid = 0;
      };
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps) news contacts calendar tasks maps spreed mail cookbook;
        integration_immich = pkgs.fetchNextcloudApp {
          url = "https://github.com/xXRoxXeRXx/integration_immich/releases/download/v1.3.0/integration_immich.tar.gz";
          hash = "sha256-qj17akAhoXQjIWmBts1a8pinS4usXq5iV5SrVcqrTrQ=";
          license = "agpl3Only";
        };
      };
      extraAppsEnable = true;
    };

  };

}
