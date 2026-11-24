{
  imports = [ ../../modules/zsh.nix ];

  programs.zsh.oh-my-zsh.plugins = [
    "sudo"
    "ssh-agent"
  ];
}
