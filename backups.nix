{ config, ... }:
{
  age.secrets = {
    "restic/password".file = ./secrets/restic/password.age;
    "restic/environment".file = ./secrets/restic/environment.age;
  };
  services.restic.backups.home = with config.users.users.emmberkat; {
    repository = "s3:https://minio.emmberkat.com/mthwate-restic/crystal";
    passwordFile = config.age.secrets."restic/password".path;
    environmentFile = config.age.secrets."restic/environment".path;
    extraBackupArgs = [
      "--skip-if-unchanged"
    ];
    paths = [
      "${home}"
    ];
    exclude = [
      "${home}/.cache"
      "${home}/.local/share/Steam/steamapps"
      "${home}/.local/share/Trash"
      "${home}/Music"
      "${home}/Videos"
      "${home}/Whipper"
      "${home}/Downloads"
      "${home}/.zsh_history"
      "${home}/.lesshst"
      "${home}/.config/obsidian"
      "${home}/.config/vlc"
      "${home}/.config/discord"
      "${home}/.local/share/TelegramDesktop"
      "${home}/.mozilla/firefox"
      "${home}/.local/share/Steam/ubuntu*"
      "${home}/.local/share/Steam/config"
      "${home}/.local/share/Steam/appcache"
      "${home}/.local/share/Steam/logs"
      "${home}/.local/share/Steam/*.dll"
      "${home}/.local/share/Steam/controller_base"
      "${home}/.local/share/Steam/depotcache"
      "${home}/.local/share/Steam/linux32"
      "${home}/.local/share/Steam/linux64"
      "${home}/.local/share/Steam/package"
      "${home}/.local/share/Steam/legacycompat"
      "${home}/.local/share/Steam/steamui"
      "${home}/.steam/*.pid"
      "${home}/.steam/*.token"
      "${home}/.compose-cache"
      "${home}/.local/state"
      "${home}/.ssh/environment-crystal"
      "${home}/.moc"
      "${home}/.bash_history"
      "${home}/.Xauthority"
      "${home}/.local/share/Steam/.crash"
      "${home}/.steam/registry.vdf"
      "${home}/.local/share/Steam/update_hosts_cached.vdf"
      "${home}/.local/share/Steam/installscriptevalutor_log.txt"
      "${home}/.config/QtProject.conf"
    ];
  };
}
