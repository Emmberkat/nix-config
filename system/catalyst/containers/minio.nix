{ config, ... }:
let
  ipAddress = "10.2.0.1";
in
{
  services.traefik.dynamicConfigOptions.http = {
    routers = {
      minio = {
        rule = "Host(`minio.emmberkat.com`)";
        entrypoints = "websecure";
        service = "minio";
        tls.certresolver = "letsencrypt";
      };
      minioConsole = {
        rule = "Host(`console.minio.emmberkat.com`)";
        entrypoints = "websecure";
        service = "minioConsole";
        tls.certresolver = "letsencrypt";
      };
    };
    services = {
      minio.loadBalancer.servers = [{ url = "http://${ipAddress}:9000"; }];
      minioConsole.loadBalancer.servers = [{ url = "http://${ipAddress}:9001"; }];
    };
  };
  age.secrets."minio/credentials".file = ../secrets/minio/credentials.age;
  containers.minio = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";
    ephemeral = true;
    bindMounts = {
      "/var/lib/minio/data" = {
        hostPath = "/mnt/b531ad05-4769-4b89-a2ae-ecf66b637b55/containers/storage/volumes/minio_data/_data";
        isReadOnly = false;
      };
      "${config.age.secrets."minio/credentials".path}" = {
        hostPath = config.age.secrets."minio/credentials".path;
        isReadOnly = true;
      };
    };
    config =
      let
        parentConfig = config;
      in
      { ... }:
      {
        boot.isContainer = true;
        system.stateVersion = parentConfig.system.stateVersion;
        nixpkgs.config.allowUnfree = parentConfig.nixpkgs.config.allowUnfree;
        networking.useHostResolvConf = false;
        networking.firewall.allowedTCPPorts = [
          9000
          9001
        ];
        systemd.network = {
          enable = true;
          networks = {
            "10-eth" = {
              matchConfig.Type = "ether";
              networkConfig = {
                Address = "${ipAddress}/8";
                Gateway = "10.0.0.1";
                DNS = "10.0.0.1";
              };
            };
          };
        };
        services.minio = {
          enable = true;
          listenAddress = "${ipAddress}:9000";
          consoleAddress = "${ipAddress}:9001";
          rootCredentialsFile = parentConfig.age.secrets."minio/credentials".path;
        };
      };
  };
}
