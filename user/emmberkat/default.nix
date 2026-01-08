{
  config,
  pkgs,
  ...
}:
{

  imports = [
    ./desktop.nix
    ./git.nix
    ./zsh.nix
  ];

  home.stateVersion = "22.11";
  nixpkgs.config.allowUnfree = true;
  programs.tmux.enable = true;

}
