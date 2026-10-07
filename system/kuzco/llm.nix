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
      metrics = true;

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
      # q8_0 KV is 34 KiB/token here (16 full-attention layers x 4 KV heads x
      # 256) vs 18 KiB at q4_0, so 144K at q8_0 costs about what 262K did at
      # q4_0, which loaded with ~1.9 GB VRAM free.
      ctx-size = 147456;
      # One consumer, one slot. llama-server defaults to 4, and each slot
      # reserves the full context: that left 154 MiB free and the server took
      # a ROCm out-of-memory abort on its first real prompt. With one slot a
      # 89,144-token request completes with 1,086 MiB still free.
      parallel = 1;
      flash-attn = "on";
      # Prompt cache, in host RAM. Each ~60K-token conversation snapshot is
      # about 4.3 GB, and the 8192 MiB default holds exactly one, so every
      # turn evicted the last and reprocessed the whole prompt: ~80 s at
      # ~730 tok/s, against a logged prefix similarity of 0.977. kuzco has
      # 62 GB of RAM and the model lives in VRAM, so there is room to keep
      # several conversations resident.
      cache-ram = 32768;
      # q4_0 K degrades long-context recall on Qwen. Mixed q8_0 K / q4_0 V has
      # no flash-attn kernel in the default build (GGML_CUDA_FA_QUANTS).
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      # Default output cap for requests without max_tokens; a repetition
      # loop once generated 186K tokens over 70 minutes.
      n-predict = 32768;
      # Multi-token prediction. Measured on IQ4_XS: ~0.6 draft acceptance,
      # 66 tok/s at <16K depth falling to 44 tok/s past 96K.
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
