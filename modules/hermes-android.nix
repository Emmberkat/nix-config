{ pkgs, ... }:
{
  # systemd's uaccess only grants the local seat user; hermes logs in over SSH.
  environment.systemPackages = [ pkgs.android-tools ];
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{ID_DEBUG_APPLIANCE}=="android", GROUP="android", MODE="0660"
  '';
  users = {
    groups.android = { };
    users.hermes.extraGroups = [ "android" ];
  };
}
