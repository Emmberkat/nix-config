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
  };

}
