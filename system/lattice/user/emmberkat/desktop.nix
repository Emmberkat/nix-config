{
  pkgs,
  ...
}:
{
  # Icons for waybar's tray, which resolves them from the user profile.
  home.packages = [ pkgs.networkmanagerapplet ];

  # waybar's tray only speaks StatusNotifierItem, so nm-applet needs --indicator.
  xsession.preferStatusNotifierItems = true;
  services.network-manager-applet.enable = true;
}
