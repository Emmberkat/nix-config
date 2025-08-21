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
  };
  security.polkit.enable = true;
  home-manager.users.emmberkat = {
    wayland.windowManager.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      config = {
        modifier = "Mod4";
        terminal = "${pkgs.wezterm}/bin/wezterm";
      };
    };
    programs = {
      waybar = {
        enable = true;
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
