{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    swaybg
    nautilus
    file-roller
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
