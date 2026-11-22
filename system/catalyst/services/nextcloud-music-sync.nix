{ config, pkgs, ... }:

let
  # emmberkat's Nextcloud account owns the Music folder (the same account the
  # nextcloud-mcp-server authenticates as). The app-password is an age secret.
  ncUser = "emmberkat";
  ncHost = "nextcloud.emmberkat.com";
  # The Jellyfin music library on local btrfs. nextcloudcmd keeps its sync DB
  # here, so the dir must be writable by emmberkat (it is: group-writable by
  # jellyfin, and emmberkat is a member of that group).
  localDir = "/mnt/media/music";
in
{
  age.secrets."nextcloud-music-sync/password" = {
    file = ../secrets/nextcloud-music-sync/password.age;
    owner = "emmberkat";
    group = "jellyfin";
    mode = "0400";
  };

  systemd.services.nextcloud-music-sync = {
    description = "Pull emmberkat's Nextcloud Music folder into the Jellyfin library";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "mnt-media.mount" ];
    wants = [ "network-online.target" "mnt-media.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "emmberkat";
      Group = "jellyfin";
      # New files must land world-readable (644) so Jellyfin can stream them.
      UMask = "0022";
      # nextcloudcmd is a Qt app and core-dumps without a display; offscreen
      # gives it a headless platform so the oneshot can run unattended.
      Environment = [ "QT_QPA_PLATFORM=offscreen" ];
      EnvironmentFile = [ config.age.secrets."nextcloud-music-sync/password".path ];
      ExecStart = ''
        ${pkgs.nextcloud-client}/bin/nextcloudcmd \
          --non-interactive \
          --user ${ncUser} \
          --password "$NEXTCLOUD_PASSWORD" \
          --max-sync-retries 5 \
          --path /Music \
          ${localDir} \
          https://${ncHost}
      '';
    };
  };

  systemd.timers.nextcloud-music-sync = {
    description = "Periodically sync the Jellyfin music library from Nextcloud";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Every 10 minutes. Persistent=true catches up a missed run after downtime.
      OnCalendar = "*:0/10";
      Persistent = true;
      AccuracySec = "1min";
    };
  };
}
