{
  config,
  pkgs,
  ...
}:
{

  imports = [
    ./backups.nix
    ./browser.nix
    ./desktop.nix
    ./git.nix
    ./zsh.nix
  ];

  home.stateVersion = "22.11";
  nixpkgs.config.allowUnfree = true;

}
