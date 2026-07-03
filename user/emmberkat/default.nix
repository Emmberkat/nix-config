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

  nixpkgs.config.allowUnfree = true;
  programs = {
    tmux.enable = true;
    zellij.enable = true;
    obsidian.enable = true;
  };

}
