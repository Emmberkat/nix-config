{ config, pkgs, ... }:
let
  comfyPort = 8188;
in
{
  services = {
    # Native nixpkgs ComfyUI (pkgs.comfyui) — torch is already built against
    # CUDA 13, so GPU acceleration works with no extra input, overlay, or
    # cachix. Models are NOT baked into the build: drop .safetensors into
    # /var/lib/comfyui/models/{diffusion_models,loras,text_encoders,vae,checkpoints}
    # (or install ComfyUI-Manager and use its model downloader).
    comfyui = {
      enable = true;
      # Listen on all interfaces; LAN-only exposure is enforced by the nginx
      # proxy ACL below (allow 127.0.0.1/32 + 10.0.0.0/8, deny all), so the
      # service itself stays unreachable from outside.
      listen = [ "0.0.0.0" "::" ];
      port = comfyPort;
    };

    nginx.virtualHosts."comfy.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString comfyPort}";
        proxyWebsockets = true;
        extraConfig = ''
          allow 127.0.0.1/32;
          allow 10.0.0.0/8;
          deny all;
        '';
      };
    };
  };
}
