{
  pkgs,
  ...
}:
{

  imports = [
    ./audio.nix
    ./backups.nix
    ./bluetooth.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
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

  services.openssh.enable = true;

  systemd = {
    network.enable = true;
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
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

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/18b1ec7a-ed6e-40cd-82c9-6c73a83f3608";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/F0AA-4486";
      fsType = "vfat";
    };
    "/home" = {
      device = "/dev/disk/by-uuid/332890ec-38ea-43d7-a455-42d685000ab5";
      fsType = "btrfs";
    };
  };

  nixpkgs = {
    hostPlatform = "x86_64-linux";
    config.allowUnfree = true;
  };

  networking = {
    useNetworkd = true;
    hostName = "crystal";
    firewall.enable = true;
  };

  time.timeZone = "US/Pacific";

  i18n.defaultLocale = "en_US.UTF-8";

  nix = {
    gc.automatic = true;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    channel.enable = false;
  };

  programs.zsh.enable = true;

  users.users.emmberkat = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "22.11";

}
