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
    tumbler.enable = true;
    gvfs.enable = true;
  };

  security = {
    polkit.enable = true;
    pam.services.swaylock = { };
  };
  # Home Manager writes the GTK color-scheme to dconf.
  programs.dconf.enable = true;

  xdg.portal = {
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common = {
      default = [ "wlr" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      # wlr has no Settings portal; gtk exposes color-scheme to Firefox and libadwaita apps.
      "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
    };
  };
}
