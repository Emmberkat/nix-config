{ config, pkgs, ... }:
let
  comfyPort = 8188;
in
{
  services = {
    # Native nixpkgs ComfyUI. The default pkgs.comfyui ships a CPU-only torch
    # (its torch override sets cudaPackages but not cudaSupport=true, and
    # config.cudaSupport defaults to false), so the service crash-looped on a
    # "Torch not compiled with CUDA enabled" assertion. pkgsCuda is a nixpkgs
    # variant with cudaSupport=true, so its comfyui's torch is built against
    # CUDA 13 and the RTX 3060 is used. Models are NOT baked into the build:
    # drop .safetensors into
    # /mnt/comfyui/models/{diffusion_models,loras,text_encoders,vae,checkpoints}
    # (or install ComfyUI-Manager and use its model downloader).
    comfyui = {
      enable = true;
      package = pkgs.pkgsCuda.comfyui;
      # Listen on all interfaces; LAN-only exposure is enforced by the nginx
      # proxy ACL below (allow 127.0.0.1/32 + 10.0.0.0/8, deny all), so the
      # service itself stays unreachable from outside.
      listen = [ "0.0.0.0" "::" ];
      port = comfyPort;
      # Keep models, outputs and custom nodes on the data disk (comfyui btrfs
      # subvolume, mounted in ../default.nix) instead of the small root drive.
      dataDir = "/mnt/comfyui";
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

  # The /mnt/comfyui mount is nofail so a missing subvolume can't drop catalyst
  # into emergency mode at boot; this keeps ComfyUI from starting (and writing
  # to the root drive underneath the mount point) unless it is actually mounted.
  systemd.services.comfyui.unitConfig.RequiresMountsFor = [ "/mnt/comfyui" ];
}
