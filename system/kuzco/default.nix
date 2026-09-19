{
  pkgs,
  ...
}:

{
  imports = [
    ../common
    ./llm.nix
  ];

  boot = {
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

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    # Pulls in rocmPackages.clr and clr.icd, which is what llama.cpp's ROCm
    # build needs at runtime. crystal does the equivalent by hand.
    amdgpu.opencl.enable = true;
  };

  networking.hostName = "kuzco";

  systemd.network.networks."10-eth" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = "10.1.0.2/8";
      Gateway = "10.0.0.1";
      DNS = "10.0.0.1";
    };
  };

  services = {
    openssh.enable = true;
    smartd.enable = true;
    prometheus.exporters = {
      node.enable = true;
      node.openFirewall = true;
      smartctl.enable = true;
      smartctl.openFirewall = true;
    };
  };

  users.users.emmberkat = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    curl
    wget
    tmux
    htop
    ncdu
    smartmontools
    amdgpu_top
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
  ];

  time.timeZone = "UTC";

  nix.gc = {
    dates = "weekly";
    options = "--delete-older-than 90d";
  };

  system.stateVersion = "26.11";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/1d61c126-d0c3-461b-8855-1f8db513b3cc";
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/E3B0-A729";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
