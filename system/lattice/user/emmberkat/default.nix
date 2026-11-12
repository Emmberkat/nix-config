{
  pkgs,
  ...
}:
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

  # The declarative half of the same install: activation merges the settings
  # into the on-disk config.yaml and symlinks the plugins. backend.mode stays
  # "none" and the gateway is off, so no service starts.
  services.hermes-agent = {
    enable = true;

    settings.plugins.enabled = [ "git-review" ];

    extraPlugins = [
      (pkgs.fetchFromGitHub {
        owner = "mister-ideas";
        repo = "git-review";
        rev = "a1944377c3f8d5699668b67379be9bf63ca0cee7";
        hash = "sha256-gO0wovB/OIxMLWLF2KovISyTL+8eA+oKGlsjMfs2rEI=";
      })
    ];
  };
}
