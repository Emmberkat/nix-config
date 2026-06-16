{ config, pkgs, ... }:
{
  imports = [
    ./homeassistant.nix
    ./jellyfin.nix
    ./llm.nix
    ./minecraft.nix
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
