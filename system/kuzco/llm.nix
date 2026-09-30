{
  pkgs,
  ...
}:
let
  llamaPort = 8041;
in
{
  services.llama-cpp = {
    enable = true;
    package = pkgs.pkgsRocm.llama-cpp;

    # catalyst's nginx proxies llama.emmberkat.com here, so unlike catalyst's
    # localhost-only server this one has to listen on the LAN. The vhost
    # already restricts callers to 10.0.0.0/8.
    openFirewall = true;

    settings = {
      host = "0.0.0.0";
      port = llamaPort;

      # The dense 27B, not catalyst's Qwen3.6-35B-A3B MoE. This is the model
      # measured on crystal's 7900 XTX, and on the same task it made 12 distinct
      # tool calls and delivered an answer in 10m49s where the MoE model made 21
      # identical repeats and died twice. llama-server fetches it into
      # LLAMA_CACHE on first start, so there is no GGUF to copy by hand.
      #
      # Uncensored (abliterated) build: huihui-ai re-quantizes straight from
      # unsloth's own GGUF weights, so this file is the same base model and
      # the same dynamic quant family as unsloth/Qwen3.8-27B-GGUF, just with
      # refusals ablated. huihui-ai's card notes MTP and the vision tower are
      # left unmodified, so draft-mtp below still applies.
      hf-repo = "huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF";
      hf-file = "Huihui-Qwen3.8-27B-abliterated-UD-IQ4_XS.gguf";
      alias = "Qwen3.8-27B";

      n-gpu-layers = 99;
      # Full native window. UD-IQ4_XS (14.40 GB, MTP head embedded as
      # blk.64.nextn.* -- confirmed against the file's own GGUF header) frees
      # enough VRAM over UD-Q4_K_XL (17.38 GB) to fit the full 262,144-token
      # window instead of the 98,304 the Q4 quant was capped at, but only
      # once cache-type-k/v below also drop to q4_0: at q8_0 the KV cache
      # alone would need ~8.6 GiB and the total overruns kuzco's 24 GiB card
      # by measurement-calibrated estimate (fixed overhead of ~3 GiB for
      # compute buffers, the 48 linear-attention layers' recurrent state, and
      # MTP scaffolding, plus ~1 GiB of peak growth during deep-prompt
      # processing -- both derived from this host's own 98K-context load and
      # peak VRAM figures before this change). At q4_0 the full window's KV
      # cache is ~4.3 GiB, landing around 22.8 GiB total with ~3 GiB margin.
      # Trade-off: IQ4_XS is a measurable step down from Q4_K_XL in published
      # BF16-relative quality tests (top-1 token agreement ~95.4% vs ~96.0%),
      # and q4_0 KV is coarser than q8_0, which costs the most exactly at the
      # deep-context end this change is meant to unlock. Re-measure actual
      # VRAM and tok/s on kuzco after this change -- everything above is
      # arithmetic, not a live measurement of this exact config.
      ctx-size = 262144;
      # Four slots sharing one 256K pool: Home Assistant (pinned to slot 3),
      # Hermes sessions and subagents. Slots are capped at 128K, so the pool
      # is 2x oversubscribed: when it fills, idle slots are purged first, and
      # only if the running requests alone exceed 256K do they all fail.
      # Hermes reads the 128K slot size from /props and compacts at ~96K.
      # Idle slots are not flushed to cache-ram, so HA's slot stays resident
      # while Hermes runs.
      parallel = 4;
      kv-unified = "";
      kv-unified-per-slot = 131072;
      no-cache-idle-slots = "";
      flash-attn = "on";
      # q4_0, not the q8_0 this ran at through 98,304 ctx: reaching the full
      # 262,144 window on a 24 GiB card requires the coarser KV quant (see
      # ctx-size above for the arithmetic). This is the one change here that
      # trades quality specifically at the deep-context end the larger window
      # exists to serve, so if agentic tool-call reliability regresses at
      # high context, this is the first setting to revisit. Requires flash
      # attention.
      # Prompt cache, in host RAM. Each ~60K-token conversation snapshot is
      # about 4.3 GB, and the 8192 MiB default holds exactly one, so every
      # turn evicted the last and reprocessed the whole prompt: ~80 s at
      # ~730 tok/s, against a logged prefix similarity of 0.977. kuzco has
      # 62 GB of RAM and the model lives in VRAM, so there is room to keep
      # several conversations resident.
      cache-ram = 32768;
      cache-type-k = "q4_0";
      cache-type-v = "q4_0";
      # Multi-token prediction. Draft acceptance reached 1.00 on a deep prompt
      # here, with generation at 47 tok/s -- measured against UD-Q4_K_XL at
      # q8_0 KV, before the IQ4_XS + q4_0 KV switch above. Re-measure: a
      # coarser draft model and a coarser KV cache can both change acceptance
      # rate.
      spec-type = "draft-mtp";
      jinja = "";
      # Cap thinking so a squeezed context can't eat the whole output budget.
      # 2026-09-21: an 88,750-token prompt left ~9.5K tokens for output and
      # the model spent it all reasoning, so the turn ended with no visible
      # answer and OpenClaw surfaced "Agent couldn't generate a response"
      # after two reasoning-only retries. At 4096 the model must stop
      # thinking and answer, leaving ~5K for the reply even at the
      # worst-case prompt depth.
      reasoning-budget = 4096;

      temp = 0.6;
      top-k = 20;
      top-p = 0.95;
      presence-penalty = 0.0;
    };
  };

  # The model is fetched over the network on first start, and network.target
  # alone does not mean the link is actually up.
  systemd.services.llama-cpp = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
}
