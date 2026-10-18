{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    swaybg
    nautilus
    file-roller
    nextcloud-client
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
      assigns."4" = [ { class = "^steam$"; } ];
      startup = [
        {
          command = "swaybg -i .background-image";
        }
      ];
      modifier = "Mod4";
      menu = "${pkgs.wofi}/bin/wofi --show drun";
      terminal = "${pkgs.foot}/bin/foot";
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
