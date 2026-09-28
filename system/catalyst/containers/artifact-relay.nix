{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "artifacts.emmberkat.com";
  port = 8100;

  # Upstream pins requires-python <3.13 because its Docker image ships 3.12,
  # but nixpkgs only caches the default interpreter's package set: on 3.12
  # the whole FastAPI closure builds from source and fastapi's test deps fail.
  # The upstream test suite runs below on this interpreter instead.
  python = pkgs.python3;

  artifact-relay = python.pkgs.buildPythonPackage rec {
    pname = "artifact-relay";
    version = "1.3.0";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "eloktev";
      repo = "artifact-relay";
      rev = "v${version}";
      hash = "sha256-uEMtJTdN/2dobAzTB5I6jdc4dfYCjoXBw3iaAsUtufE=";
    };

    build-system = [ python.pkgs.hatchling ];

    # Upstream pins markdown-it-py <4 (from its uv.lock); nixpkgs ships 4.x.
    # The rendering/sanitizer tests in checkPhase are what vouch for 4.x.
    pythonRelaxDeps = [ "markdown-it-py" ];

    dependencies =
      with python.pkgs;
      [
        fastapi
        uvicorn
        jinja2
        python-multipart
        pydantic
        pydantic-settings
        itsdangerous
        argon2-cffi
        markdown-it-py
        mdit-py-plugins
        pygments
        nh3
        pillow
      ]
      ++ uvicorn.optional-dependencies.standard;

    nativeCheckInputs = with python.pkgs; [
      pytestCheckHook
      httpx
      defusedxml
      pyyaml
    ];

    # Only the helper shell scripts (bootstrap/publish/backup/restore) need
    # curl/docker, which the sandbox lacks; none of them are part of this
    # deployment. test_missing_secrets... re-execs python with PYTHONPATH
    # stripped, so it cannot import the package from the Nix store. Every
    # test of the service itself still runs.
    disabledTestPaths = [
      "tests/test_distribution.py"
      "tests/test_first_artifact_activation.py"
      "tests/test_managed_backup_restore_shell.py"
      "tests/test_publish_file_shell.py"
      "tests/test_restore_shell.py"
    ];
    disabledTests = [ "test_missing_secrets_fail_fast_with_a_clear_message" ];

    pythonImportsCheck = [ "artifact_relay.config" ];
  };

  env = python.withPackages (_: [ artifact-relay ]);
in
{
  # Private publisher for long Markdown/HTML results from Hermes (the
  # artifact-relay plugin in hermes.nix). Single user: the API is bearer-token
  # authenticated, the viewer is behind one password, and share links are off.
  #
  # The env file holds ARTIFACT_API_TOKEN, VIEW_PASSWORD_HASH (Argon2id) and
  # SESSION_SECRET_KEY. Hermes reads the same token as ARTIFACT_RELAY_API_TOKEN
  # from hermes/artifact-relay-env, so rotate both files together.
  age.secrets."artifact-relay/environment".file = ../secrets/artifact-relay/environment.age;

  systemd.services.artifact-relay = {
    description = "Artifact Relay";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      BASE_URL = "https://${domain}";
      DATA_DIR = "/var/lib/artifact-relay";
      COOKIE_SECURE = "true";
      SHARE_LINKS_ENABLED = "false";
      # nginx is the only proxy peer; uvicorn trusts X-Forwarded-* from it alone.
      FORWARDED_ALLOW_IPS = "127.0.0.1";
    };

    serviceConfig = {
      ExecStart = lib.escapeShellArgs [
        "${env}/bin/uvicorn"
        "artifact_relay.main:app"
        "--host"
        "127.0.0.1"
        "--port"
        (toString port)
        "--proxy-headers"
        "--no-access-log"
        "--workers"
        "1"
      ];
      EnvironmentFile = config.age.secrets."artifact-relay/environment".path;
      DynamicUser = true;
      StateDirectory = "artifact-relay";
      # pydantic-settings also looks for ./.env; keep the cwd to an empty, owned dir.
      WorkingDirectory = "/var/lib/artifact-relay";
      Restart = "on-failure";

      NoNewPrivileges = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://127.0.0.1:${toString port}";
  };
}
