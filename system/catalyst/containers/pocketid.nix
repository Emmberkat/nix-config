{ config, ... }:
{
  age.secrets."pocketid/key" = {
  file = ../secrets/pocketid/key.age;
  owner = "pocket-id";
  };

  services = {
    nginx.virtualHosts = {
      "auth.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:1411";
        };
      };
    };

    pocket-id = {
      enable = true;
      settings = {
        APP_URL = "https://auth.emmberkat.com";
        PORT = 1411;
        ENCRYPTION_KEY_FILE = config.age.secrets."pocketid/key".path;
        TRUST_PROXY = true;
      };
    };
  };


}
