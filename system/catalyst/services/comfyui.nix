{ config, pkgs, ... }:
let
  comfyPort = 8188;
  comfyHost = "comfy.emmberkat.com";
  # Pocket ID OIDC client (Public, PKCE S256). Callback URL registered on it:
  #   https://comfy.emmberkat.com/oauth2/callback
  pocketIdClientId = "975ccd04-79d6-424d-9a1e-047c74c2e4b4";
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

    nginx.virtualHosts.${comfyHost} = {
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

    # ComfyUI has no auth of its own, so oauth2-proxy gates the vhost against
    # Pocket ID via nginx auth_request (the oauth2-proxy-nginx module adds the
    # /oauth2/ locations and the auth_request directive). Port 8188 is not in
    # the firewall, so nginx is the only way in. The LAN ACL above still
    # applies on top of the login.
    oauth2-proxy = {
      enable = true;
      provider = "oidc";
      oidcIssuerUrl = "https://auth.emmberkat.com";
      clientID = pocketIdClientId;
      # The Pocket ID client is Public (PKCE S256). oauth2-proxy refuses to
      # start without a client secret, and Pocket ID ignores the secret for
      # public clients, so this is a fixed non-secret placeholder (same as
      # nextcloud.nix's user_oidc provider).
      clientSecretFile = "${pkgs.writeText "pocketid-public-client-secret" "public-client-pkce"}";
      cookie.secretFile = config.age.secrets."comfyui/oauth2-proxy-cookie-secret".path;
      redirectURL = "https://${comfyHost}/oauth2/callback";
      email.addresses = "emmabenkart@gmail.com";
      reverseProxy = true;
      trustedProxyIP = [ "127.0.0.1/32" ];
      setXauthrequest = true;
      # Module defaults are "force" (consent screen on every login) and
      # passing a Basic auth header upstream, which ComfyUI doesn't use.
      approvalPrompt = "auto";
      passBasicAuth = false;
      extraConfig = {
        code-challenge-method = "S256";
        # Go straight to Pocket ID instead of oauth2-proxy's "Sign in" page.
        skip-provider-button = true;
      };
      nginx = {
        domain = comfyHost;
        virtualHosts.${comfyHost} = { };
      };
    };
  };

  # 32 random bytes (base64url) for oauth2-proxy's session cookie encryption.
  # Read by systemd via LoadCredential, so root ownership is fine.
  age.secrets."comfyui/oauth2-proxy-cookie-secret".file =
    ../secrets/comfyui/oauth2-proxy-cookie-secret.age;

  # The /mnt/comfyui mount is nofail so a missing subvolume can't drop catalyst
  # into emergency mode at boot; this keeps ComfyUI from starting (and writing
  # to the root drive underneath the mount point) unless it is actually mounted.
  systemd.services.comfyui.unitConfig.RequiresMountsFor = [ "/mnt/comfyui" ];
}
