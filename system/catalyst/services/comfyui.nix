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
    # (or use Manager -> Model Manager in the UI, enabled below).
    comfyui = {
      enable = true;
      # withManager bundles ComfyUI-Manager (off by default in nixpkgs). The
      # legacy UI flag is required for model downloads: only the legacy
      # Manager UI has the Model Manager (the new frontend's built-in manager
      # handles custom nodes only). Use Manager -> Model Manager to download
      # catalog models into <dataDir>/models on catalyst. Custom nodes that
      # need extra Python deps won't install at runtime (the Python env is in
      # the read-only Nix store); add those via Nix instead.
      package = pkgs.pkgsCuda.comfyui.override { withManager = true; };
      extraArgs = [ "--enable-manager-legacy-ui" ];
      # Loopback only: nginx (below) is the only client. This also matters to
      # the Manager, which refuses installs at its default security_level
      # unless ComfyUI listens on a loopback address.
      listen = [ "127.0.0.1" ];
      port = comfyPort;
      # Keep models, outputs and custom nodes on the data disk (comfyui btrfs
      # subvolume, mounted in ../default.nix) instead of the small root drive.
      dataDir = "/mnt/comfyui";
    };

    nginx.virtualHosts."comfy.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString comfyPort}";
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
