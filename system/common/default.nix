{
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
  };

  systemd.network.enable = true;

  nixpkgs.config.allowUnfree = true;

  networking = {
    useDHCP = false;
    firewall.enable = true;
    enableIPv6 = false;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  nix = {
    gc.automatic = true;
    settings = {
      download-buffer-size = 536870912;
      trusted-substituters = [
        "https://cache.nixos-cuda.org"
        "s3://emmberkat-nix-cache?region=sea&endpoint=minio.emmberkat.com"
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
