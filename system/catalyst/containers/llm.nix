{ pkgs, config, ... }:
let
  openwebuiPort = 8040;
  llamaPort = 8041;

  # Sampling per the Qwen model card. llama.cpp's defaults make this model look
  # broken, so a profile is always selected explicitly rather than left off.
  samplingProfiles = {
    # Thinking mode: precise coding and agentic tool-calling.
    coding = {
      temp = 0.6;
      top-p = 0.95;
      top-k = 20;
      presence-penalty = 0.0;
    };
    # Instruct / non-thinking conversational use.
    chat = {
      temp = 0.7;
      top-p = 0.80;
      presence-penalty = 1.5;
    };
  };
  activeProfile = "coding";
in
{
  services = {
    nginx.virtualHosts = {
      "llm.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString openwebuiPort}";
          proxyWebsockets = true;
        };
      };
      "llama.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString llamaPort}";
          proxyWebsockets = true;
          extraConfig = ''
            allow 127.0.0.1/32;
            allow 10.0.0.0/8;
            deny all;
          '';
        };
      };
    };

    open-webui = {
      enable = true;
      port = openwebuiPort;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
      };
    };

    llama-cpp = {
      enable = true;
      package = pkgs.pkgsCuda.llama-cpp;
      settings = {
        alias = "Qwen3.6-35B-A3B-UD-Q4_K_XL-MTP";
        # Fetched at runtime into LLAMA_CACHE (/var/cache/llama-cpp, which the
        # module already provisions, backed by the pool's models subvol) rather
        # than pinned as a Nix derivation.
        # A fetchurl pin would put 22GB into catalyst's closure, and
        # .github/workflows/check.yml builds every host's toplevel on a
        # GitHub-hosted runner -- which would drag the weights down on every PR
        # and almost certainly exhaust the runner's disk.
        #
        # The cost is that this is unpinned: -hf selects a quant, not a
        # revision, so there is no integrity check. That matters more than usual
        # here -- see the repo note below. If throughput quietly drops by ~25%,
        # suspect an upstream re-upload that dropped the MTP layer, and check
        # for blk.40/nextn tensors before assuming the tuning drifted.
        hf-repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
        hf-file = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
        port = llamaPort;

        # Every layer goes on the GPU; it is the MoE *expert* weights that get
        # pushed to system RAM via n-cpu-moe. Offloading whole layers instead is
        # the classic way to tank throughput here, so no `fit`/`n-gpu-layers auto`.
        n-gpu-layers = 99;
        # Measured, not guessed. Re-measure after a llama.cpp or model bump, with
        # frigate running and at full ctx-size -- 30 looks fine at depth 0 and
        # OOMs at 64K once the KV is actually allocated. 32 is faster
        # (40 vs 36 tok/s) but only fits while frigate is stopped, and OOMs once
        # the cameras come back -- 36 leaves ~1.3GB of headroom for frigate and
        # wyoming-whisper, which together hold ~3.2GB of this card.
        n-cpu-moe = 36;
        # Qwen3.6's MTP head does self-speculative decoding with no draft model,
        # worth ~+25%. Note the repo above is Qwen3.6-35B-A3B-MTP-GGUF, not the
        # similarly named Qwen3.6-35B-A3B-GGUF: both ship a UD-Q4_K_XL with the
        # same imatrix calibration, but the latter strips blk.40 (block_count 40
        # vs 41, 733 tensors vs 753, no nextn_predict_layers) and this flag then
        # has nothing to run.
        spec-type = "draft-mtp";

        # 64K. Note `parallel` is left at 1 deliberately: llama.cpp divides the
        # context between slots, so the previous `parallel = 4` would have meant
        # 16K per conversation, not 64K.
        ctx-size = 65536;
        flash-attn = "on";
        # Prompt-prefix reuse across turns, which agent loops hit constantly.
        cache-reuse = 256;
        # Chat template drives tool-call formatting. Tool calling does not work
        # without this.
        jinja = "";
        # Weights read into RAM up front rather than paged from disk, and pinned
        # so the kernel cannot evict experts mid-session.
        no-mmap = "";
        mlock = "";
      }
      // samplingProfiles.${activeProfile};
    };
  };

  # settings.mlock is a no-op without this: the default RLIMIT_MEMLOCK is 8MB,
  # so llama-server fails to pin the ~22GB of weights and quietly carries on
  # with them evictable -- exactly what mlock was meant to prevent.
  systemd.services.llama-cpp.serviceConfig.LimitMEMLOCK = "infinity";

  # The weights live on the pool, mounted over systemd's CacheDirectory. Without
  # this ordering llama-cpp can win the race against the mount, have
  # CacheDirectory= recreate the dir on the SSD, and re-download 22GB -- which
  # the mount then hides, stranding the space.
  systemd.services.llama-cpp.unitConfig.RequiresMountsFor = "/var/cache/private/llama-cpp";

}
