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
  xdg.portal = {
    wlr.enable = true;
    config.common = {
      default = [ "wlr" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
  };
}
