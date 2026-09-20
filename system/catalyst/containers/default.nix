{ config, pkgs, ... }:
{
  imports = [
    ./garage.nix
    ./homeassistant.nix
    ./immich.nix
    ./jellyfin.nix
    ./llm.nix
    ./nextcloud.nix
    ./openclaw.nix
    ./searx.nix
    ./unifi.nix
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

  # ddclient is DynamicUser and its ExecStartPre runs `install -o ddclient`, so
  # the transient user must be resolvable before the prestart does. The module
  # orders the unit only After=network.target, so at boot it races nscd and dies
  # with "install: invalid user 'ddclient'". It then recovers on the next timer
  # firing, which is why this looked like a transient network blip rather than an
  # ordering bug.
  systemd.services.ddclient.after = [ "nss-user-lookup.target" ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    clientMaxBodySize = "0";
    virtualHosts."emmberkat.com" = {
      default = true;
      enableACME = true;
      forceSSL = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "emmabenkart@gmail.com";
  };

}
