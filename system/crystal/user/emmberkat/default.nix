{
  config,
  pkgs,
  ...
}:
{

  imports = [
    ./backups.nix
    ./desktop.nix
  ];

  # The gateway token is shared with catalyst: secrets.nix encrypts the same
  # .age file for both hosts, so crystal decrypts catalyst's copy.
  age.secrets."openclaw/gateway-token" = {
    file = ../../../catalyst/secrets/openclaw/gateway-token.age;
  };

  programs.openclaw = {
    enable = true;
    # Node-only host: the module would otherwise start a local gateway user
    # service here, which is pointless when crystal only talks to catalyst.
    systemd.enable = false;
    # This machine is a node — it connects to catalyst as a remote Gateway.
    # No own gateway, no channels, no local model provider.
    config = {
      gateway = {
        remote = {
          url = "http://10.1.0.1:18789";
          token = {
            source = "env";
            provider = "default";
            id = "OPENCLAW_GATEWAY_TOKEN";
          };
        };
      };
    };
  };

  # The nix-openclaw module only knows how to start a gateway, so the node
  # host is a small hand-rolled user service. The wrapper reads the
  # age-decrypted token into OPENCLAW_GATEWAY_TOKEN at startup (same pattern
  # as the module's gateway wrapper), so the token never lands in the Nix
  # store. The agenix user service decrypts it into
  # $XDG_RUNTIME_DIR/agenix first; the node waits for it and retries.
  systemd.user.services.openclaw-node = {
    Unit = {
      Description = "OpenClaw node host (crystal -> catalyst gateway)";
      After = [
        "network-online.target"
        "agenix.service"
      ];
      Wants = [
        "network-online.target"
        "agenix.service"
      ];
    };
    Service = {
      Type = "simple";
      ExecStart =
        let
          wrapper = pkgs.writeShellScriptBin "openclaw-node" ''
            tokenFile=${config.age.secrets."openclaw/gateway-token".path}
            if [ ! -f "$tokenFile" ]; then
              echo "openclaw-node: token file $tokenFile not found yet" >&2
              exit 1
            fi
            export OPENCLAW_GATEWAY_TOKEN="$(cat "$tokenFile")"
            exec ${pkgs.openclaw}/bin/openclaw node run \
              --host 10.1.0.1 \
              --port 18789 \
              --display-name crystal
          '';
        in
        "${wrapper}/bin/openclaw-node";
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
