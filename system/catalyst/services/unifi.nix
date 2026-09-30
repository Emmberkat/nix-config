{ pkgs, ... }: {

  services = {

    nginx.virtualHosts = {
      "unifi.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "https://localhost:8443";
          proxyWebsockets = true;
          extraConfig = ''
            allow 127.0.0.1/32;
            allow 10.0.0.0/8;
            deny all;
          '';
        };
      };
    };

    unifi = {
      enable = true;
      openFirewall = true;
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.mongodb-ce;
    };

    # unifi rotates its own java logs (server.log.1 and friends) but ships
    # mongod with no rotation at all, so mongod.log grows without bound. It
    # reached 59GB here and filled the root filesystem, which also starves
    # /tmp and therefore nix builds.
    logrotate.settings."/var/log/unifi/mongod.log" = {
      frequency = "daily";
      # Size as well as frequency: this log can put on gigabytes in a day, and
      # once the disk is full mongod logs write errors, which grows it faster.
      size = "100M";
      rotate = 3;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      # mongod holds the fd open and does not reopen on rename, so a plain
      # rotate would leave it writing to the unlinked inode and reclaim
      # nothing. copytruncate keeps the same inode.
      copytruncate = true;
      # /var/log/unifi is unifi-owned, and logrotate refuses to act on
      # directories it does not own without this.
      su = "unifi unifi";
    };
  };

}
