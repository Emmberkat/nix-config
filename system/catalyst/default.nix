{ pkgs, ... }:

let
  dataUuid = "b531ad05-4769-4b89-a2ae-ecf66b637b55";
  dataDisk = "/dev/disk/by-uuid/${dataUuid}";
  dataMount = "/mnt/${dataUuid}";
  subvol = name: extra: {
    device = dataDisk;
    fsType = "btrfs";
    options = [ "subvol=${name}" ] ++ extra;
  };
in
{
  imports = [
    ../common
    ./services
  ];

  systemd = {
    network = {
      networks = {
        "10-eth" = {
          matchConfig.Type = "ether";
          networkConfig = {
            Address = "10.1.0.1/8";
            Gateway = "10.0.0.1";
            DNS = "10.0.0.1";
          };
        };
      };
    };
  };

  networking.hostName = "catalyst";

  users = {
    users = {
      emmberkat.extraGroups = [ "jellyfin" ];
      # Read-only journal access for the agent (journalctl, no sudo needed).
      hermes.extraGroups = [ "systemd-journal" ];
    };
  };

  security.sudo.extraRules = [
    # Let the agent deploy this host: run nixos-rebuild (switch/boot/...) as
    # root without a password. Mirrors the btrbk module's pattern of listing
    # both the store path and the /run/current-system/sw/bin path, so the rule
    # keeps working across nixpkgs updates.
    {
      users = [ "hermes" ];
      commands = [
        {
          command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    neovim
    curl
    wget
    tmux
    htop
    smartmontools
    ncdu
    nh
    git
    gh
  ];

  services = {
    openssh.enable = true;
    smartd.enable = true;
    prometheus.exporters = {
      node.enable = true;
      node.openFirewall = true;
      smartctl.enable = true;
      smartctl.openFirewall = true;
    };

    btrbk.instances.backups = {
      settings = {
        volume = {
          ${dataMount} = {
            subvolume = {
              home = {
                snapshot_create = "onchange";
              };
              docker = {
                snapshot_create = "onchange";
              };
            };
            snapshot_dir = "backups";
            snapshot_preserve = "48h 14d 6w *m *y";
            snapshot_preserve_min = "14d";
          };
        };
      };
    };
  };

  nix.gc = {
    dates = "weekly";
    options = "--delete-older-than 90d";
  };

  system.stateVersion = "23.05";

  boot = {
    devShmSize = "4G";
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "sr_mod"
    ];
    kernelModules = [ "kvm-amd" ];
  };

  time.timeZone = "UTC";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/95d9413a-95b9-4525-945b-fdcf0acbf943";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/9CF4-7FD3";
      fsType = "vfat";
    };

    ${dataMount} = {
      device = dataDisk;
      fsType = "btrfs";
    };

    "/home" = subvol "home" [ ];
    "/var/lib/frigate" = subvol "frigate" [ "noatime" ];
    "/mnt/hass" = subvol "hass" [ "noatime" ];
    "/media" = subvol "hass_media" [ "noatime" ];
    "/mnt/sws" = subvol "sws" [ "noatime" ];
    "/mnt/media" = subvol "media" [ "noatime" ];
    "/mnt/garage-data" = subvol "garage-data" [ "noatime" ];
    "/mnt/garage-meta" = subvol "garage-meta" [ "noatime" ];
    "/mnt/immich" = subvol "immich" [ "noatime" ];
    "/mnt/comfyui" = subvol "comfyui" [
      "noatime"
      "nofail"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/0a97e7b1-5e81-4833-8cce-eb50a945b265"; }
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware = {
    cpu.amd.updateMicrocode = true;
    graphics = {
      enable = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = false;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
    };
  };

}
