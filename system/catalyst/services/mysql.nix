{ pkgs, ... }:
{
  # Local clients only: over the socket, signed in as their own Unix user.
  services.mysql = {
    enable = true;
    package = pkgs.mysql84;
    settings.mysqld.skip-networking = true;
    ensureDatabases = [ "muster" ];
    ensureUsers = [
      {
        name = "hermes";
        ensurePermissions."muster.*" = "ALL PRIVILEGES";
      }
    ];
  };
}
