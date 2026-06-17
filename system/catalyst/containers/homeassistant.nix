{
  config,
  pkgs,
  lib,
  ...
}:
let
  port = 8042;
  swsPort = 8787;
in
{

  age.secrets = {
    "frigate/environment".file = ../secrets/frigate/environment.age;
  };

  systemd.services.frigate.serviceConfig.EnvironmentFile =
    config.age.secrets."frigate/environment".path;

  services = {
    nginx.virtualHosts = {
      "home.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString port}";
          proxyWebsockets = true;
        };
      };
      "frigate.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
      };
    };
    home-assistant = {
      enable = true;
      openFirewall = true;
      customComponents = with pkgs.home-assistant-custom-components; [
        frigate

        (pkgs.buildHomeAssistantComponent rec {
          owner = "valentinfrlch";
          domain = "llmvision";
          version = "1.6.0";

          src = pkgs.fetchFromGitHub {
            owner = "valentinfrlch";
            repo = "ha-llmvision";
            tag = "v${version}";
            hash = "sha256-Bt6InfyPhC5gHNE/6w+M0WEL8hmv1Fxxeh6FrpsJCsQ=";
          };

          dependencies = with pkgs.home-assistant.python3Packages; [
            boto3
            aiosqlite
            aiofile
          ];

          ignoreVersionRequirement = [
            "boto3"
            "aiosqlite"
            "aiofile"
          ];

        })

      ];

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
        "habitica"
        "steam_online"
        "google"
        "google_mail"
        "ring"
        "tesla_fleet"
        "jellyfin"
        "litterrobot"
        "onvif"
        "lutron_caseta"
        "reolink"
      ];
      configDir = "/mnt/hass";
      config = {
        default_config = { };
        homeassistant = {
          allowlist_external_dirs = [ "/media" ];
        };
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

    mosquitto = {
      enable = true;
      listeners = [
        {
          acl = [ "pattern readwrite #" ];
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
        }
      ];
    };

    frigate = {
      enable = true;
      package = pkgs.cudaPackages_12.pkgs.frigate;
      checkConfig = false;
      hostname = "frigate.emmberkat.com";
      vaapiDriver = "nvidia";
      settings = {
        ffmpeg.hwaccel_args = "preset-nvidia";
        face_recognition = {
          enabled = true;
          model_size = "small";
        };

        detectors = {
          onnx_0 = {
            type = "onnx";
          };
        };

        model = {
          model_type = "yolo-generic";
          width = 640;
          height = 640;
          input_tensor = "nchw";
          input_dtype = "float";
          input_pixel_format = "rgb";
          labelmap_path = ./coco-80.txt;
          path = pkgs.stdenv.mkDerivation {
            name = "yolo26";
            buildInputs = [
              (pkgs.python3.withPackages (
                ps: with ps; [
                  ultralytics
                  onnxruntime
                  onnx
                  onnxslim
                ]
              ))
            ];
            src = pkgs.fetchurl {
              url = "https://github.com/ultralytics/assets/releases/download/v8.4.0/yolo26m.pt";
              hash = "sha256-QBzqmrI60ZJG/3dEhZgWvFmfNQ6Tyd0wNntvCgdF0Lc=";
            };
            dontUnpack = true;
            buildPhase = ''
              cp $src yolo.pt
              yolo export model=yolo.pt format=onnx end2end=False imgsz=640 simplify=True opset=17
            '';
            installPhase = ''
              cp yolo.onnx $out
            '';
          };
        };

        classification.custom = {
          cats = {
            enabled = true;
            name = "cats";
            threshold = 0.8;
            object_config = {
              objects = [ "cat" ];
              classification_type = "sub_label";
            };
          };

        };

        detect.enabled = true;
        objects.track = [
          "person"
          "cat"
          "dog"
          "cell phone"
          "laptop"
        ];
        record = {
          enabled = true;
          continuous.days = 3;
          motion.days = 7;
          alerts.retain = {
            days = 30;
            mode = "all";
          };
          detections.retain = {
            days = 30;
            mode = "all";
          };
        };
      };
      settings.mqtt = {
        enabled = true;
        host = "localhost";
      };
      settings.cameras = {
        "front_door" = {
          ffmpeg.inputs = [
            {
              path = "rtsp://frigate:{FRIGATE_RTSP_PASSWORD}@10.0.1.135:554/Preview_01_main";
              roles = [
                "detect"
                "record"
                "audio"
              ];
            }
          ];
        };
        "entry_stairs" = {
          ffmpeg.inputs = [
            {
              path = "rtsp://frigate:{FRIGATE_RTSP_PASSWORD}@10.0.1.132:554/cam/realmonitor?channel=1&subtype=0";
              roles = [
                "detect"
                "record"
                "audio"
              ];
            }
          ];
        };
        "living_room" = {
          ffmpeg.inputs = [
            {
              path = "rtsp://frigate:{FRIGATE_RTSP_PASSWORD}@10.0.1.131:554/cam/realmonitor?channel=1&subtype=0";
              roles = [
                "detect"
                "record"
                "audio"
              ];
            }
          ];
        };
      };
    };

  };

  networking.firewall.allowedTCPPorts = [ swsPort ];

}
