{
  pkgs,
  ...
}:
{
  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
          user = "emmberkat";
        };
      };
    };
    gnome.gnome-keyring.enable = true;
    tumbler.enable = true; # Generate thumbnails
    gvfs.enable = true;
  };
  security.polkit.enable = true;
  home-manager.users.emmberkat = {
    home.packages = with pkgs; [
      swaybg

      discord
      picard
    ];
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
  };
}
