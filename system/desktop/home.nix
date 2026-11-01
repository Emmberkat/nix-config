{
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    swaybg
    nautilus
    file-roller
    nextcloud-client
    makemkv
  ];

  # Shows polkit password prompts (e.g. fprintd-enroll); sway has no agent.
  services.polkit-gnome.enable = true;

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
  };
  qt = {
    enable = true;
    style.name = "adwaita-dark";
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
      terminal = "${pkgs.foot}/bin/foot";
      keybindings = lib.mkOptionDefault {
        "--locked XF86AudioRaiseVolume" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
        "--locked XF86AudioLowerVolume" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "--locked XF86AudioMute" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "--locked XF86AudioMicMute" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      };
      bars = [ ];
    };
  };
  programs = {
    foot.enable = true;
    swaylock.enable = true;
    waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          modules-left = [ "sway/workspaces" ];
          modules-center = [ "sway/window" ];
          # battery hides itself on machines without one.
          modules-right = [
            "wireplumber"
            "cpu"
            "memory"
            "temperature"
            "battery"
            "clock"
            "tray"
          ];
        };
      };
    };
  };
}
