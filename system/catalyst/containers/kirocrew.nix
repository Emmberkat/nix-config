{ config, ... }:
let
  port = config.home-manager.users.emmberkat.services.kirocrew.port;
in
{
  home-manager.users.emmberkat.services.kirocrew.enable = true;

  # kirocrew runs as a home-manager *user* service (see modules/kirocrew) so
  # it shares the real ~/.kiro state with interactive sessions. That means
  # its systemd unit lives in emmberkat's own systemd instance, which only
  # starts at boot — without a login session — if lingering is enabled.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/emmberkat 0644 root root -"
  ];

  # The gateway requires a valid token on every request regardless of bind
  # address, so proxying it is safe. The socket itself stays loopback-only
  # (KIROCREW_BIND=127.0.0.1 in the module) — this vhost is the only way in.
  #
  # One-time step after first deploy: kirocrew also checks the Host header
  # against its own `dashboard.url` config (a DNS-rebinding guard), so it
  # must be told its public URL or it will reject requests through this
  # vhost:
  #   kirocrew config set dashboard.url https://kirocrew.emmberkat.com
  #   systemctl --user restart kirocrew
  services.nginx.virtualHosts."kirocrew.emmberkat.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString port}";
      proxyWebsockets = true;
    };
  };
}
