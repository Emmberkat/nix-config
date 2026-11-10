{ ... }:
{
  imports = [
    ./desktop.nix
  ];

  # The Hermes Agent CLI on emmberkat's PATH, with HERMES_HOME exported for
  # interactive shells. No daemon: the laptop runs the client only.
  programs.hermes-agent.enable = true;
}
