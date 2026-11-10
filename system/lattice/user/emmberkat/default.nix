{ ... }:
{
  imports = [
    ./desktop.nix
  ];

  # The Hermes Agent on emmberkat's laptop: the CLI on PATH with HERMES_HOME
  # exported for interactive shells, plus the desktop application and its
  # launcher. No daemon: the laptop runs the client only.
  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };
}
