{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8890;

  # The local embedder and reranker are an optional extra, left out upstream
  # to keep torch out of the default closure.
  hindsight = pkgs.llm-agents.hindsight.overridePythonAttrs (old: {
    dependencies = old.dependencies ++ old.optional-dependencies.local-ml;
  });
in
{
  users = {
    users.hindsight = {
      isSystemUser = true;
      group = "hindsight";
    };
    groups.hindsight = { };
  };

  services.postgresql = {
    ensureDatabases = [ "hindsight" ];
    ensureUsers = [
      {
        name = "hindsight";
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
    extensions = ps: [ ps.pgvector ];
  };

  systemd.services = {
    # pgvector is not a trusted extension, so the owner role can't create it.
    postgresql-setup.serviceConfig.ExecStartPost =
      let
        sql = pkgs.writeText "hindsight-setup.sql" ''
          CREATE EXTENSION IF NOT EXISTS "vector";
          CREATE EXTENSION IF NOT EXISTS "pg_trgm";
          CREATE EXTENSION IF NOT EXISTS "btree_gin";
          ALTER SCHEMA public OWNER TO hindsight;
        '';
      in
      [ "${lib.getExe' config.services.postgresql.package "psql"} -d hindsight -f ${sql}" ];

    hindsight = {
      description = "Hindsight agent memory server";
      after = [ "postgresql-setup.service" ];
      requires = [ "postgresql-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOME = "/var/lib/hindsight";
        HF_HOME = "/var/lib/hindsight/huggingface";
        HINDSIGHT_API_HOST = "127.0.0.1";
        HINDSIGHT_API_PORT = toString port;
        HINDSIGHT_API_DATABASE_URL = "postgresql://hindsight@/hindsight?host=/run/postgresql";
        HINDSIGHT_API_LLM_PROVIDER = "openai";
        HINDSIGHT_API_LLM_BASE_URL = "http://10.1.0.2:8041/v1";
        HINDSIGHT_API_LLM_API_KEY = "llama-cpp-local";
        HINDSIGHT_API_LLM_MODEL = "Qwen3.8-27B";
        HINDSIGHT_API_LLM_EXTRA_BODY = builtins.toJSON {
          chat_template_kwargs.enable_thinking = false;
        };
        HINDSIGHT_API_LLM_MAX_CONCURRENT = "1";
      };
      serviceConfig = {
        ExecStart = lib.getExe hindsight;
        User = "hindsight";
        Group = "hindsight";
        StateDirectory = "hindsight";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
