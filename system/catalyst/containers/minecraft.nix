{ config, pkgs, ... }:
let
  atm10_files = pkgs.fetchzip {
    url = "https://mediafilez.forgecdn.net/files/7294/979/ServerFiles-5.3.1.zip";
    hash = "sha256-I2zBOHjgtV1gWogWVbplc0zzMh0EQxRqrIkpJ7AYdR4=";
    stripRoot = false;
  };

  mc-router = pkgs.buildGoModule {
    name = "mc-router";
    vendorHash = "sha256-1fdK1JXc0TfWakXCBfH07Ui1grHKv4nY1i8+Fpc0/w4=";
    src = pkgs.fetchFromGitHub {
      owner = "itzg";
      repo = "mc-router";
      rev = "v1.37.0";
      hash = "sha256-DIoAM3JSRcXIvK7g/f8qPKcHJ8kMM5KXEbyZapL4IeU=";
    };
  };

in
{

  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];

  systemd.services.mc-router = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    script = "${mc-router}/bin/mc-router";
    environment = {
      MAPPING = ''
        atm10.minecraft.emmberkat.com=10.1.0.1:25566
        vanilla.minecraft.emmberkat.com=10.1.0.1:25567
      '';
    };
  };

  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    servers.vanilla = {
      enable = false;
      package = pkgs.minecraftServers.vanilla-1_21_10;
      serverProperties = {
        server-port = 25567;
        server-ip = "10.1.0.1";
      };
    };

    servers.atm10 = {
      enable = true;
      package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_215;
      serverProperties = {
        server-port = 25566;
        server-ip = "10.1.0.1";
        allow-flight = true;
        motd = "All the Mods 10";
        max-tick-time = 180000;
      };
      files = {
        "config" = "${atm10_files}/config";
        "datapacks" = "${atm10_files}/datapacks";
        "defaultconfigs" = "${atm10_files}/defaultconfigs";
        "kubejs" = "${atm10_files}/kubejs";
        "local" = "${atm10_files}/local";
        "mods" = "${atm10_files}/mods";
      };
      jvmOpts = [
        "-Xms4G"
        "-Xmx8G"
        "-XX:+UseG1GC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DisableExplicitGC"
        "-XX:+AlwaysPreTouch"
        "-XX:G1NewSizePercent=30"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem"
        "-XX:MaxTenuringThreshold=1"
      ];
    };

  };

}
