{
  config,
  pkgs,
  ...
}:
{

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
      "ahci"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
      "sr_mod"
    ];
    kernelModules = [ "kvm-intel" ];
  };

  services = {
    openssh.enable = true;
    # Vial talks to the keyboard over hidraw; its rules grant a normal user
    # access to it. QMK is not involved: qmk-udev-rules targets bootloader
    # devices for flashing firmware, which Vial does not do.
    udev.packages = [ pkgs.vial ];
  };

  # Temporarily used for iOS access
  services.usbmuxd.enable = true;

  systemd = {
    network = {
      networks = {
        "10-eth" = {
          matchConfig.Type = "ether";
          networkConfig.DHCP = "ipv4";
        };
      };
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [ rocmPackages.clr.icd ];
    };
  };

  environment.systemPackages = with pkgs; [
    vial
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/d6007436-3e0d-48be-a852-677c3995ddb1";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/D537-F5B1";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
    "/home" = {
      device = "/dev/disk/by-uuid/332890ec-38ea-43d7-a455-42d685000ab5";
      fsType = "btrfs";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/f27e0a00-03bb-43c6-b9f0-900d7e456ad7"; }
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "crystal";

  time.timeZone = "US/Pacific";

  programs.zsh.enable = true;

  users.users.emmberkat = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "25.11";

  programs = {
    zoom-us.enable = true;

    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };

}
