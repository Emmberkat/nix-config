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
  };

  i18n.defaultLocale = "en_US.UTF-8";

  nix = {
    gc.automatic = true;
    settings = {
      trusted-substituters = [
        "s3://emmberkat-nix-cache?region=sea&endpoint=minio.emmberkat.com"
      ];
      trusted-public-keys = [
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
