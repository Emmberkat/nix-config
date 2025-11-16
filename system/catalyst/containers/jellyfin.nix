{ config, pkgs, ... }:
let
  port = 8096;
in
{
  services.traefik.dynamicConfigOptions.http = {
    routers = {
      jellyfin = {
        rule = "Host(`jellyfin.emmberkat.com`)";
        entrypoints = "websecure";
        service = "jellyfin";
        tls.certresolver = "letsencrypt";
      };
    };
    services.jellyfin.loadBalancer.servers = [ { url = "http://localhost:${toString port}"; } ];
  };
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    #dataDir = "/mnt/media";
  };


}
