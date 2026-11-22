_:
let
  host = "torrent.emmberkat.com";
  webuiPort = 8100;
  torrentingPort = 6881;
  savePath = "/mnt/media/Downloads";
in
{
  services = {
    qbittorrent = {
      enable = true;
      inherit webuiPort torrentingPort;
      serverConfig = {
        LegalNotice.Accepted = true;
        # oauth2-proxy is the login: the WebUI listens on loopback only and
        # skips its own auth for loopback clients, which is all nginx is.
        Preferences.WebUI = {
          Address = "127.0.0.1";
          LocalHostAuth = false;
        };
        BitTorrent.Session = {
          DefaultSavePath = savePath;
          DHTEnabled = false;
          PeXEnabled = false;
          LSDEnabled = false;
        };
      };
    };

    oauth2-proxy.nginx.virtualHosts.${host} = { };

    nginx.virtualHosts.${host} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString webuiPort}";
        proxyWebsockets = true;
      };
    };
  };

  systemd.tmpfiles.settings.qbittorrent-downloads.${savePath}.d = {
    user = "qbittorrent";
    group = "qbittorrent";
    mode = "755";
  };

  networking.firewall = {
    allowedTCPPorts = [ torrentingPort ];
    allowedUDPPorts = [ torrentingPort ];
  };
}
