{ config, pkgs, ... }:

{

  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    servers.vanilla = {
      enable = true;
      package = pkgs.minecraftServers.vanilla-1_21_10;
    };

  };

}
