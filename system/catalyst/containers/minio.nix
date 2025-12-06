{ config, ... }:
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
      minio.loadBalancer.servers = [ { url = "http://localhost:9000"; } ];
      minioConsole.loadBalancer.servers = [ { url = "http://localhost:9001"; } ];
    };
  };
  age.secrets."minio/credentials".file = ../secrets/minio/credentials.age;

  networking.firewall.allowedTCPPorts = [
    9000
    9001
  ];
  services.minio = {
    enable = true;
    region = "sea";
    dataDir = [ "/mnt/minio" ];
    listenAddress = ":9000";
    consoleAddress = ":9001";
    rootCredentialsFile = config.age.secrets."minio/credentials".path;
  };
}
