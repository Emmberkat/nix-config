{ config, ... }:
{
  services.nginx.virtualHosts = {
    "minio.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:9000";
    };
    "console.minio.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:9001";
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
