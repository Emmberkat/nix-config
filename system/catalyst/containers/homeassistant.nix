{ config, pkgs, ... }:
let
  port = 8042;
  swsPort = 8787;
in
{
  services = {
    nginx.virtualHosts."home.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString port}";
        proxyWebsockets = true;
      };
    };
    home-assistant = {
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
        "litterrobot"
        "onvif"
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

    wyoming = {
      piper.servers.hass = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";

        voice = "jarvis-high";
        extraArgs =
          let
            repo = pkgs.fetchgit {
              url = "https://huggingface.co/jgkawell/jarvis";
              rev = "37f8763122312665f091d1fc760abaf1f79b02cc";
              fetchLFS = true;
              hash = "sha256-yqKRDc4FyavsrrMvwVvImXGFwLj/Kxtc36JIKL0HJNE=";
            };
          in
          [
            "--data-dir"
            "${repo}/en/en_GB/jarvis/medium"
            "--data-dir"
            "${repo}/en/en_GB/jarvis/high"
          ];
      };

      faster-whisper = {
        package = pkgs.pkgsCuda.wyoming-faster-whisper;
        servers.hass = {
          enable = true;
          uri = "tcp://0.0.0.0:10300";
          language = "en";
          model = "medium.en";
          device = "cuda";
        };
      };

    };
  };

  networking.firewall.allowedTCPPorts = [ swsPort ];

}
