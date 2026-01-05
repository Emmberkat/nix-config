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
    kernelModules = [ "kvm-amd" ];

    # Sets the correct boot menu orientation on the steam deck.
    loader.systemd-boot.consoleMode = "5";
  };

  networking.hostName = "emmberdeck";

  networking.networkmanager.enable = true;

  jovian.steam.enable = true;
  jovian.steam.autoStart = true;
  jovian.devices.steamdeck.enable = true;

  jovian.steam.user = "deck";

  users.users.deck = {
    isNormalUser = true;
  };

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
