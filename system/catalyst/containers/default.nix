{ config, pkgs, ... }:
{
  imports = [
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  age.secrets = {
    "ddclient/password".file = ../secrets/ddclient/password.age;
  };

  services.ddclient = {
    enable = true;
    protocol = "namecheap";
    server = "dynamicdns.park-your-domain.com";
    username = "emmberkat.com";
    passwordFile = config.age.secrets."ddclient/password".path;
    domains = [
      "@.emmberkat.com"
      "*.emmberkat.com"
    ];
  };

  services.traefik = {
    enable = true;
    staticConfigOptions = {
      providers.docker = false;
      api = {
        dashboard = true;
        insecure = true;
      };
      certificatesresolvers.letsencrypt.acme = {
        tlschallenge = true;
        email = "emmabenkart@gmail.com";
        storage = "${config.services.traefik.dataDir}/acme.json";
      };
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
          };
        };
        websecure.address = ":443";
      };
    };
    dynamicConfigOptions.http = {
      routers.traefik = {
        rule = "Host(`traefik.emmberkat.com`)";
        entrypoints = "websecure";
        service = "traefik";
        middlewares = "internal";
        tls.certresolver = "letsencrypt";
      };
      services.traefik.loadbalancer.servers = [{ url = "http://localhost:8080"; }];
      middlewares.internal.ipallowlist.sourcerange = "127.0.0.1/32, 10.0.0.0/8";
    };
  };
}
