{ pkgs, ... }:
{
  # Local clients sign in over the socket as their own Unix user. LAN clients
  # get TLS-only TCP; the read-only account is made once by hand:
  #   sudo mysql -e "CREATE USER 'muster_ro'@'10.%' IDENTIFIED BY RANDOM PASSWORD; GRANT SELECT ON muster.* TO 'muster_ro'@'10.%'"
  services.mysql = {
    enable = true;
    package = pkgs.mysql84;
    settings.mysqld = {
      bind-address = "0.0.0.0";
      require_secure_transport = true;
    };
    ensureDatabases = [ "muster" ];
    ensureUsers = [
      {
        name = "hermes";
        ensurePermissions."muster.*" = "ALL PRIVILEGES";
      }
    ];
  };

  networking.firewall.interfaces.enp4s0.allowedTCPPorts = [ 3306 ];
}
