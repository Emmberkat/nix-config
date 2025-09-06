{
  pkgs,
  config,
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
}
