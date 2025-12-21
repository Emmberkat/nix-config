{ pkgs
, config
, ...
}:
{


  age.secrets = {
    "syncthing/cert".file = ./secrets/syncthing/cert.age;
    "syncthing/key".file = ./secrets/syncthing/key.age;
  };

  home.packages = with pkgs; [
    swaybg
    discord
    picard
    leocad
    prismlauncher
  ];

  services.syncthing = {
    enable = true;
    cert = config.age.secrets."syncthing/cert".path;
    key = config.age.secrets."syncthing/key".path;

    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "Pixel 9 Pro Fold" = {
          id = "7CX57MN-BK5VPUZ-LY24SUX-DY6URT2-ZLE4MJR-LWUJEC5-45LNELE-B33HRQY";
        };
        "Pixel 10 Pro Fold" = {
          id = "F7UDS5N-J5H4JYF-KS3WUD3-WCBZIVF-VNOGEQN-4AXWA3M-QY3AZHT-KCCXYAI";
        };
      };
      folders = {
        "Obsidian" = {
          path = "~/Documents/Obsidian";
          devices = [
            "Pixel 9 Pro Fold"
            "Pixel 10 Pro Fold"
          ];
        };
        "Music" = {
          path = "~/Music";
          devices = [
            "Pixel 9 Pro Fold"
            "Pixel 10 Pro Fold"
          ];
          type = "sendonly";
        };
      };
    };
  };

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    config = {
      startup = [
        {
          command = "swaybg -i .background-image";
        }
      ];
      modifier = "Mod4";
      menu = "${pkgs.wofi}/bin/wofi --show drun";
      terminal = "${pkgs.wezterm}/bin/wezterm";
      bars = [ ];
      output = {
        DP-3 = {
          pos = "0 0";
        };
        DP-1 = {
          pos = "1920 0";
        };
        DP-2 = {
          pos = "4480 0";
        };
      };
      workspaceOutputAssign = [
        {
          workspace = "1";
          output = "DP-3";
        }
        {
          workspace = "2";
          output = "DP-1";
        }
        {
          workspace = "3";
          output = "DP-2";
        }
        {
          workspace = "4";
          output = "DP-1";
        }
        {
          workspace = "5";
          output = "DP-1";
        }
        {
          workspace = "6";
          output = "DP-1";
        }
        {
          workspace = "7";
          output = "DP-1";
        }
        {
          workspace = "8";
          output = "DP-1";
        }
        {
          workspace = "9";
          output = "DP-1";
        }
        {
          workspace = "0";
          output = "DP-1";
        }
      ];
    };
  };
  programs = {
    swaylock.enable = true;
    waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          modules-left = [ "sway/workspaces" ];
          modules-center = [ "sway/window" ];
          modules-right = [
            "wireplumber"
            "cpu"
            "memory"
            "temperature"
            "clock"
            "tray"
          ];
        };
      };
    };
  };

}
