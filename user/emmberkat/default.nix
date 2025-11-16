{
  config,
  pkgs,
  agenix,
  ...
}:
{

  imports = [
    ./backups.nix
    ./desktop.nix
    ./git.nix
    ./neovim.nix
    ./zsh.nix
    agenix.homeManagerModules.default
  ];

  home.stateVersion = "22.11";
  nixpkgs.config.allowUnfree = true;

}
