{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kirocrew;
in
{
  options.services.kirocrew = {
    enable = lib.mkEnableOption "Kiro Crew, a persistent local AI agent workspace";

    package = lib.mkPackageOption pkgs "kirocrew" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5476;
      description = "Port the gateway dashboard listens on.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/agenix/kirocrew/environment";
      description = ''
        Path to an EnvironmentFile with secrets such as messaging-channel
        tokens, kept out of the world-readable Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # This is a home-manager user service rather than a NixOS system
    # service specifically so it runs with the user's real $HOME:
    # kiro-cli sign-in and all interactive `kirocrew` sessions live under
    # ~/.kiro, and the gateway needs to see the same state, not an
    # isolated copy under /var/lib. Enabling this also requires lingering
    # for the user (`loginctl enable-linger`, or the declarative
    # equivalent) so the user's systemd instance — and this service —
    # comes up at boot without a login session.
    systemd.user.services.kirocrew = {
      Unit = {
        Description = "Kiro Crew gateway";
      };

      Service = {
        ExecStart = "${lib.getExe cfg.package} gateway";
        Environment = [
          "KIROCREW_PORT=${toString cfg.port}"
          # Pinned so the socket stays loopback-only even once dashboard.url
          # (set via `kirocrew config set`) names a public host — otherwise
          # kirocrew widens its own bind to 0.0.0.0 and a reverse proxy in
          # front of it is no longer the only way in.
          "KIROCREW_BIND=127.0.0.1"
        ];
        Restart = "on-failure";
        RestartSec = 10;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        # NOT RestrictNamespaces: kirocrew's own agent sandbox needs
        # unshare(CLONE_NEWUSER) to isolate agent subprocesses. Restricting
        # it here fails that probe with EPERM and kirocrew falls back to
        # refusing unsandboxed execution entirely.
        RestrictRealtime = true;
        LockPersonality = true;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
