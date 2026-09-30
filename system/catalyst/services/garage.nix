{ pkgs, config, ... }: {

  age.secrets."garage/rpc_secret" = {
    file = ../secrets/garage/rpc_secret.age;
    owner = "garage";
    group = "garage";
    mode = "0400";
  };

  services = {

    nginx.virtualHosts = {
      "s3.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:3900";
          proxyWebsockets = true;
        };
      };
      "nix.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:3902";
          proxyWebsockets = true;
        };
      };
    };

    garage = {
      enable = true;
      package = pkgs.garage;
      settings = {
        metadata_dir = "/mnt/garage-meta";
        data_dir = "/mnt/garage-data";
        replication_factor = 1;
        rpc_bind_addr = "[::]:3901";
        rpc_secret_file = config.age.secrets."garage/rpc_secret".path;
        s3_api = {
          api_bind_addr = "[::]:3900";
          s3_region = "sea";
        };
        s3_web = {
          bind_addr = "[::]:3902";
          root_domain = ".emmberkat.com";
        };
      };
    };
  };

  users.users.garage = {
    isSystemUser = true;
    group = "garage";
  };
  users.groups.garage = { };

  #systemd.services.garage.serviceConfig.ReadWritePaths = [ "/mnt/garage-data" "/mnt/garage-meta" ];
  #systemd.tmpfiles.rules = [
  #  "d /mnt/garage-data 0700 garage garage - -"
  #  "d /mnt/garage-meta 0700 garage garage - -"
  #];

}
