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

    # Hermes and Home Assistant on catalyst call this directly over the LAN;
    # there is no proxy in front of it.
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
      # q8_0 KV plus the q8_0 MTP draft KV is ~40 KiB/token. The default even
      # layer split leaves the second GPU ~2.7 GiB fuller than the first;
      # with Q6_K_XL weights, 256K peaked at 24.0 of 24.6 GiB there and 288K
      # ran out of memory.
      ctx-size = 262144;
      # Four slots share one unified KV pool, so Hermes's main session, Home
      # Assistant and two subagents each keep their prefix resident; each
      # extra slot measured ~0.5 GiB of VRAM. Sharing a slot, a Hermes turn
      # evicts HA's cached prefix and the next Jarvis request pays a cold
      # re-prefill. llama.cpp routes by LCP prefix similarity, so workloads
      # self-segregate; the HA entry additionally pins itself to slot 1
      # (llamacpp_id_slot). That pin is on the HA side, not in this repo.
      #
      # No per-slot cap: the pool already equals the model's trained window,
      # which is every slot's limit. Hermes reads it from /props and compacts
      # at 0.75 of it. Idle slots flush to cache-ram and restore from RAM
      # instead of a full re-prefill.
      parallel = 4;
      kv-unified = "";
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
      # The MTP draft has its own KV cache, which defaults to f16.
      cache-type-k-draft = "q8_0";
      cache-type-v-draft = "q8_0";
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
