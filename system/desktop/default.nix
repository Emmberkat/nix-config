_: {
  imports = [
    ./android.nix
    ./audio.nix
    ./bluetooth.nix
    ./browser.nix
    ./sway.nix
  ];

  # MakeMKV reads optical drives through the SCSI generic interface.
  boot.kernelModules = [ "sg" ];

  home-manager.users.emmberkat.imports = [ ./home.nix ];
}
