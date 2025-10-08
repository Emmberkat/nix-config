{ config, ... }:
let
  ipAddress = "10.2.0.8";
in
{
  services.traefik.dynamicConfigOptions.http = {
    routers = {
      immich = {
        rule = "Host(`photos.emmberkat.com`)";
        entrypoints = "websecure";
        service = "immich";
        tls.certresolver = "letsencrypt";
      };
    };
    services.immich.loadBalancer.servers = [ { url = "http://${ipAddress}:2283"; } ];
  };
  containers.immich = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";
    privateUsers = "pick";
    config =
      let
        parentConfig = config;
      in
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        boot.isContainer = true;
        system.stateVersion = parentConfig.system.stateVersion;
        networking.useHostResolvConf = lib.mkForce false;
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
        services.immich = {
          enable = true;
          openFirewall = true;
          host = ipAddress;
        };
      };
  };
}
