{ config, pkgs, ... }:
{
  imports = [
    (import ./instance.nix {
      user = "hermes-work";
      port = 9120;
      domain = "work.hermes.emmberkat.com";
      clientId = "c559cf36-52c3-46d1-bd47-880eede524a5";
    })
  ];

  age.secrets = {
    "hermes-work/claude-oauth-token" = {
      file = ../../secrets/hermes/claude-oauth-token.age;
      owner = "hermes-work";
    };

    "hermes-work/tokens" = {
      file = ../../secrets/hermes-work/tokens.age;
      owner = "hermes-work";
    };
  };

  home-manager.users.hermes-work.services.hermes-agent = {
    extraPackages = with pkgs; [
      curl
      diffutils
      findutils
      gawk
      gh
      gnugrep
      gnused
      gnutar
      gzip
      jq
      unzip
      which
    ];

    settings = {
      model = {
        provider = "anthropic";
        default = "claude-opus-5-5";
      };
      agent.reasoning_effort = "medium";
      approvals.mode = "off";
      telemetry.shared_metrics = {
        enabled = false;
        send = false;
      };
      terminal = {
        # Set explicitly: the config merge never removes keys from disk.
        backend = "local";
        home_mode = "profile";
      };
    };

    environmentFiles = [
      config.age.secrets."hermes-work/claude-oauth-token".path
      config.age.secrets."hermes-work/tokens".path
    ];
  };
}
