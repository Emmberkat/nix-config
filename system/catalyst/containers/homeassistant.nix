{ config, pkgs, ... }:
let
  port = 8042;
  swsPort = 8787;
in
{
  services.traefik.dynamicConfigOptions.http = {
    routers = {
      homeassistant = {
        rule = "Host(`home.emmberkat.com`)";
        entrypoints = "websecure";
        service = "homeassistant";
        tls.certresolver = "letsencrypt";
      };
      homeassistant-tesla = {
        rule = "Host(`tesla.home.emmberkat.com`)";
        entrypoints = "websecure";
        service = "homeassistant-tesla";
        middlewares = "homeassistant-tesla";
        tls.certresolver = "letsencrypt";
      };
    };
    services.homeassistant.loadBalancer.servers = [ { url = "http://localhost:${toString port}"; } ];
    services.homeassistant-tesla.loadBalancer.servers = [
      { url = "http://localhost:${toString swsPort}"; }
    ];
    middlewares.homeassistant-tesla.addPrefix.prefix = "/hass/tesla";
  };
  services.static-web-server = {
    enable = true;
    root = "/mnt/sws";
    listen = "localhost:${toString swsPort}";
  };
  networking.firewall.allowedTCPPorts = [ swsPort ];
  services.home-assistant = {
    enable = true;
    openFirewall = true;
    extraComponents = [
      "esphome"
      "zha"
      "zwave_js"
      "isal"
      "usb"
      "tts"
      "stt"
      "whisper"
      "piper"
      "wyoming"
      "ollama"
      "imap"
      "roborock"
      "met"
      "shopping_list"
      "scl"
      "tile"
      "samsungtv"
      "waze_travel_time"
      "opower"
      "immich"
      "habitica"
      "steam_online"
      "google"
      "google_mail"
      "ring"
      "tesla_fleet"
    ];
    configDir = "/mnt/hass";
    config = {
      default_config = { };
      http = {
        server_port = port;
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };
      "automation ui" = "!include automations.yaml";
      "scene ui" = "!include scenes.yaml";
      "script ui" = "!include scripts.yaml";
    };
  };

  services.wyoming = {
    piper.servers.hass = {
      enable = true;
      uri = "tcp://0.0.0.0:10200";
      voice = "en_US-danny-low";
    };

    faster-whisper.servers.hass = {
      enable = true;
      uri = "tcp://0.0.0.0:10300";
      language = "en";
    };

  };

}
