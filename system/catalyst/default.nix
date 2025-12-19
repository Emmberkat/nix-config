{ config, pkgs, ... }:

{
  imports = [
    ../common
    ./containers
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
      emmberkat = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = [ "wheel" ];
      };
    };
  };

  home-manager.users.emmberkat = {
    home.stateVersion = "22.11";
  };

  environment.systemPackages = with pkgs; [
    neovim
    curl
    wget
    tmux
    htop
    smartmontools
  ];

  programs.zsh.enable = true;

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
          "/mnt/b531ad05-4769-4b89-a2ae-ecf66b637b55" = {
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

  system.stateVersion = "22.11";

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sr_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/95d9413a-95b9-4525-945b-fdcf0acbf943";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/9CF4-7FD3";
      fsType = "vfat";
    };

    "/mnt/b531ad05-4769-4b89-a2ae-ecf66b637b55" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
    };

    "/home" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

    "/var/lib/containers" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [
        "subvol=containers"
        "noatime"
      ];
    };

    "/var/lib/nixos-containers" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [
        "subvol=nixos-containers"
        "noatime"
      ];
    };

    "/mnt/ollama" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [
        "subvol=ollama"
        "noatime"
      ];
    };

    "/mnt/minio" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [
        "subvol=minio"
        "noatime"
      ];
    };

    "/mnt/hass" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [
        "subvol=hass"
        "noatime"
      ];
    };

    "/mnt/sws" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [
        "subvol=sws"
        "noatime"
      ];
    };

    "/mnt/media" = {
      device = "/dev/disk/by-uuid/b531ad05-4769-4b89-a2ae-ecf66b637b55";
      fsType = "btrfs";
      options = [
        "subvol=media"
        "noatime"
      ];
    };

  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/0a97e7b1-5e81-4833-8cce-eb50a945b265"; }
    { device = "/swapfile"; size = 32768; }
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.config.cudaSupport = true;
  hardware.cpu.amd.updateMicrocode = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
  };

}
