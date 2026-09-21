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
      hf-repo = "unsloth/Qwen3.8-27B-GGUF";
      hf-file = "Qwen3.8-27B-UD-Q4_K_XL.gguf";
      alias = "Qwen3.8-27B-Q4_K_XL";

      n-gpu-layers = 99;
      # 96K, measured on kuzco: 22,583 MiB of 24,560 at load, peaking at
      # 23,473 MiB on an 89,144-token prompt. Prompt processing falls off with
      # depth well before the window does -- 862 tok/s at 10K, 632 at 39K,
      # 398 at 89K -- so a larger window would buy little.
      ctx-size = 98304;
      # One consumer, one slot. llama-server defaults to 4, and each slot
      # reserves the full context: that left 154 MiB free and the server took
      # a ROCm out-of-memory abort on its first real prompt. With one slot a
      # 89,144-token request completes with 1,086 MiB still free.
      parallel = 1;
      flash-attn = "on";
      # The cache is what limits context here, not the weights: crystal's own
      # 96K and 128K measurements differ by 1,409 MiB over 32,768 tokens, about
      # 44 KB per token. q8_0 roughly halves that, and costs far less quality
      # than taking a bit off every weight would. Requires flash attention.
      # Prompt cache, in host RAM. Each ~60K-token conversation snapshot is
      # about 4.3 GB, and the 8192 MiB default holds exactly one, so every
      # turn evicted the last and reprocessed the whole prompt: ~80 s at
      # ~730 tok/s, against a logged prefix similarity of 0.977. kuzco has
      # 62 GB of RAM and the model lives in VRAM, so there is room to keep
      # several conversations resident.
      cache-ram = 32768;
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      # Multi-token prediction. Draft acceptance reached 1.00 on a deep prompt
      # here, with generation at 47 tok/s.
      spec-type = "draft-mtp";
      jinja = "";

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
