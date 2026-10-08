_: {
  imports = [
    ../common
    ./audio.nix
    ./bluetooth.nix
    ./browser.nix
    ./desktop.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
      "r8169"
    ];
    kernelModules = [ "amdgpu" ];
    # Framework BIOS misreports the ACP device as wired, adding a phantom
    # interface and breaking alsa-ucm.
    blacklistedKernelModules = [
      "snd_acp70"
      "snd_acp_pci"
    ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    graphics.enable = true;
    amdgpu.initrd.enable = true;
    # iio sensor lets the desktop manage display brightness.
    sensor.iio.enable = true;
  };

  # Panel self-refresh (PSR) can hang the display on this hardware.
  # dcdebugmask bit 0x10 = disable PSR.
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x10" ];

  # AMD gets better battery life from power-profiles-daemon than TLP.
  services = {
    power-profiles-daemon.enable = true;
    fprintd.enable = true;
    fwupd.enable = true;
  };

  networking.hostName = "lattice";
  networking.networkmanager.enable = true;

  time.timeZone = "US/Pacific";

  programs = {
    steam.enable = true;
  };

  users.users.emmberkat.extraGroups = [ "networkmanager" ];

  system.stateVersion = "26.11";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/6a5c6087-06da-4101-8382-9f281235a789";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/1E90-6EF8";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
}
