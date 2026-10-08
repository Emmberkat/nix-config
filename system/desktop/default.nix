_: {
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./browser.nix
    ./sway.nix
  ];

  home-manager.users.emmberkat.imports = [ ./home.nix ];
}
