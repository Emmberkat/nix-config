{
  config,
  pkgs,
  ...
}:
{

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    swraid.enable = false;
  };

  home-manager.sharedModules = [ { home.stateVersion = config.system.stateVersion; } ];

  systemd.network.enable = true;

  nixpkgs.config.allowUnfree = true;

  networking = {
    useDHCP = false;
    firewall.enable = true;
    enableIPv6 = false;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    jq
  ];

  nix = {
    gc.automatic = true;
    settings = {
      download-buffer-size = 536870912;
      trusted-users = [
        "root"
        "@wheel"
      ];
      # Enabled, not merely permitted. These are also declared in the flake's
      # nixConfig, but flake nixConfig is ignored without --accept-flake-config,
      # so local builds silently fell back to cache.nixos.org alone and
      # recompiled every CUDA package. CI passes that flag and so was already
      # getting the cache; this makes workstation builds match.
      substituters = [
        "https://cache.nixos-cuda.org"
        "https://nix.emmberkat.com"
      ];
      # Kept so a non-root user can still opt into these explicitly.
      trusted-substituters = [
        "https://cache.nixos-cuda.org"
        "https://nix.emmberkat.com"
      ];
      trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "crystal:1ejOpnHE9Io7242e2uHtGeN2Mtcey67OyDp7qNwk5Rs="
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    channel.enable = false;
  };

}
