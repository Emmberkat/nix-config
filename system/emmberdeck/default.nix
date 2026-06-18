{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "usb_storage"
      "usbhid"
      "sd_mod"
      "sdhci_pci"
    ];
    kernelModules = [
      "kvm-amd"
      "ntsync"
    ];

    # Sets the correct boot menu orientation on the steam deck.
    loader.systemd-boot.consoleMode = "5";
  };

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "emmberdeck";

  networking.networkmanager.enable = true;

  programs.steam.gamescopeSession.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "steam-gamescope";
        user = "emmberkat";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd steam-gamescope";
        user = "emmberkat";
      };
    };
  };

  programs.steam.enable = true;

  hardware.steam-hardware.enable = true;

  programs.zsh.enable = true;

  users.users.emmberkat = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };

  time.timeZone = "US/Pacific";

  services.openssh.enable = true;

  system.stateVersion = "25.11";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/a18cfb11-cb32-4456-8f04-b4118e4bd80e";
      fsType = "btrfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/EE55-DB09";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/ff500b66-3b16-4bae-8e8a-d4c7ccd48ac9"; } ];

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = true;
}
