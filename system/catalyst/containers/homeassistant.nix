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
    };
    services.homeassistant.loadBalancer.servers = [ { url = "http://localhost:${toString port}"; } ];
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
      "webostv"
      "waze_travel_time"
      "opower"
      "immich"
      "habitica"
      "steam_online"
      "google"
      "google_mail"
      "ring"
      "tesla_fleet"
      "jellyfin"
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
      model = "medium.en";
      device = "cuda";
    };

  };

}
