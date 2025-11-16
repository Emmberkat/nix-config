{
  config,
  pkgs,
  agenix,
  ...
}:
{

  imports = [
    ./backups.nix
    ./browser.nix
    ./desktop.nix
    ./git.nix
    ./zsh.nix
    agenix.homeManagerModules.default
  ];

  home.stateVersion = "22.11";
  nixpkgs.config.allowUnfree = true;

}
