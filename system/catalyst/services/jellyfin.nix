{ config, pkgs, ... }:
let
  port = 8096;
in
{
  services.nginx.virtualHosts = {
    "jellyfin.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:${toString port}";
    };
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

}
