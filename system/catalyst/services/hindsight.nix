{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8890;

  # One llama.cpp server in router mode serves both models Hindsight needs:
  # bge-m3 for embeddings (/v1/embeddings) and bge-reranker-v2-m3 for
  # reranking (/v1/rerank). Requests are routed by their "model" field, so the
  # section names below are the model names Hindsight sends.
  llamaPort = 8891;
  models = {
    # BAAI/bge-m3, Q8_0 (~605 MiB): multilingual, 1024-dim, 8k context.
    bge-m3 = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/bge-m3-Q8_0-GGUF/resolve/main/bge-m3-q8_0.gguf";
      sha256 = "aa473d51f451a22f0fcf39ba3330c14bed38a385712b1113440f69df4047a173";
    };
    # BAAI/bge-reranker-v2-m3, Q8_0 (~606 MiB): cross-encoder on the same
    # XLM-R base as bge-m3; the reference reranker in llama.cpp's docs.
    bge-reranker-v2-m3 = pkgs.fetchurl {
      url = "https://huggingface.co/gpustack/bge-reranker-v2-m3-GGUF/resolve/main/bge-reranker-v2-m3-Q8_0.gguf";
      sha256 = "a43c7c9b11a4c1517e5bf95151960e1621d1b72f7a493364b01e386cf1aaa1d3";
    };
  };
  llamaPreset = pkgs.writeText "llama-cpp-models.ini" ''
    version = 1

    [*]
    n-gpu-layers = 99

    [bge-m3]
    model = ${models.bge-m3}
    embedding = true
    load-on-startup = true

    [bge-reranker-v2-m3]
    model = ${models.bge-reranker-v2-m3}
    reranking = true
    load-on-startup = true
  '';

  # Embeddings and reranking both run in llama.cpp, so the server needs none
  # of the upstream "local-ml" extra (torch / sentence-transformers).
  # fastmcp-slim (a dep) is marked broken against mcp >= 2, so build it in a
  # python scope with mcp pinned to mcp_1. The whole scope, not just
  # fastmcp's input: claude-agent-sdk also pulls mcp, and two versions in one
  # closure fail pythonCatchConflictsPhase.
  hindsight = pkgs.hindsight-api-slim.override {
    python3Packages = pkgs.python3Packages.overrideScope (f: _: { mcp = f.mcp_1; });
  };
in
{
  users = {
    users.hindsight = {
      isSystemUser = true;
      group = "hindsight";
    };
    groups.hindsight = { };
  };

  services = {
    postgresql = {
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

    # CUDA build on the RTX 3060 (substituted from cache.nixos-cuda.org).
    llama-cpp = {
      enable = true;
      package = pkgs.llama-cpp-cuda;
      settings = {
        port = llamaPort;
        models-preset = "${llamaPreset}";
        no-webui = true;
      };
    };
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
      after = [
        "postgresql-setup.service"
        "llama-cpp.service"
      ];
      requires = [ "postgresql-setup.service" ];
      wants = [ "llama-cpp.service" ];
      wantedBy = [ "multi-user.target" ];
      environment =
        let
          llamaUrl = "http://127.0.0.1:${toString llamaPort}";
        in
        {
          HOME = "/var/lib/hindsight";
          HINDSIGHT_API_HOST = "127.0.0.1";
          HINDSIGHT_API_PORT = toString port;
          HINDSIGHT_API_DATABASE_URL = "postgresql://hindsight@/hindsight?host=/run/postgresql";
          # LLM (retain / extraction) goes to kuzco's llama.cpp.
          HINDSIGHT_API_LLM_PROVIDER = "openai";
          HINDSIGHT_API_LLM_BASE_URL = "http://10.1.0.2:8041/v1";
          HINDSIGHT_API_LLM_API_KEY = "llama-cpp-local";
          HINDSIGHT_API_LLM_MODEL = "Qwen3.8-27B";
          HINDSIGHT_API_LLM_EXTRA_BODY = builtins.toJSON {
            chat_template_kwargs.enable_thinking = false;
          };
          HINDSIGHT_API_LLM_MAX_CONCURRENT = "1";
          # Embeddings: OpenAI-compatible /v1/embeddings on the local router.
          HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
          HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "${llamaUrl}/v1";
          HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "bge-m3";
          HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY = "llama-cpp-local";
          # Reranking: the "cohere" provider with a custom base URL posts
          # {model, query, documents} to that exact URL and reads
          # {results: [{index, relevance_score}]}, which is llama.cpp's
          # /v1/rerank format. ("tei" can't be used: it sends no model field,
          # so the router can't route it.) llama.cpp returns raw logits;
          # Hindsight sigmoid-normalizes out-of-range scores itself.
          HINDSIGHT_API_RERANKER_PROVIDER = "cohere";
          HINDSIGHT_API_RERANKER_COHERE_BASE_URL = "${llamaUrl}/v1/rerank";
          HINDSIGHT_API_RERANKER_COHERE_MODEL = "bge-reranker-v2-m3";
          HINDSIGHT_API_RERANKER_COHERE_API_KEY = "llama-cpp-local";
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
