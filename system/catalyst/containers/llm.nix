{ pkgs, config, ... }:
let
  openwebuiPort = 8040;
  ollamaPort = 8041;
  comfyPort = 8188;
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
      "ollama.emmberkat.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString ollamaPort}";
          proxyWebsockets = true;
          extraConfig = ''
            allow 127.0.0.1/32;
            allow 10.0.0.0/8;
            deny all;
          '';
        };
      };
      "comfy.emmberkat.com" = {
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

    open-webui = {
      enable = true;
      port = openwebuiPort;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        OLLAMA_API_BASE_URL = "http://localhost:${toString ollamaPort}";
      };
    };

    ollama = {
      enable = true;
      port = ollamaPort;
      user = "ollama";
      home = "/mnt/ollama";
      package = pkgs.ollama-cuda;
      openFirewall = true;
      environmentVariables = {
        OLLAMA_ORIGINS = "*";
      };
      loadModels = [
        "qwen3.5:4b"
        "qwen3.5:9b"
      ];
    };

    comfyui = {
      enable = true;
      gpuSupport = "cuda";
      port = comfyPort;
      extraArgs = [

        "--extra-model-paths-config"
        (toString (
          (pkgs.formats.yaml { }).generate "extra-path-config.yaml" {
            custom = {
              base_path = pkgs.linkFarm "models" [
                {
                  name = "text_encoders/qwen_3_4b.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors";
                    hash = "sha256-bGcUmFc6wvelUBUCzM6NKwjqbKL2YcRY5wjzazbt/Fo=";
                  };
                }
                {
                  name = "text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors";
                    hash = "sha256-wzVdMBkfHwZrJtk/ugF66YCdzmxifdpfambqplEgT2g=";
                  };
                }
                {
                  name = "text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors";
                    hash = "sha256-y1Y22FKg6mqQdasb70lsDbeu8TwCNQVx44iuqVnFwLQ=";
                  };
                }
                {
                  name = "loras/pixel_art_style_z_image_turbo.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/tarn59/pixel_art_style_lora_z_image_turbo/resolve/main/pixel_art_style_z_image_turbo.safetensors";
                    hash = "sha256-CbG0XO7QICkpvKUo5RtQII0BYPTp0roPQst+c5pDV38=";
                  };
                }
                {
                  name = "loras/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors";
                    hash = "sha256-KjLOk47HHbK0moF7SESuhplVaVGN6lbuDdwgnL6OE3c=";
                  };
                }
                {
                  name = "loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors";
                    hash = "sha256-Ak8h3glbyPrZgJ3tPp5JouFw3PJwddqBRbp9YNiqt/k=";
                  };
                }
                {
                  name = "loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors";
                    hash = "sha256-0XbICNb8RhmZto4yHvy3UBsguMN5dSPtDfFPfR3v8R4=";
                  };
                }
                {
                  name = "diffusion_models/z_image_turbo_bf16.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors";
                    hash = "sha256-JAdhMFC4Cf/f8YpKyZr4Pqa5VEPs69+A4GSnnIJVdKY=";
                  };
                }
                {
                  name = "diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors";
                    hash = "sha256-MYVo9hlRq52iEQDHuJbjwdpn8NLvrWQhVF4CLPqisrQ=";
                  };
                }
                {
                  name = "diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors";
                    hash = "sha256-VHGkV7asQEICpfvmwRWVo9VkH8dmsA84dj9yMD//wh4=";
                  };
                }
                {
                  name = "diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors";
                    hash = "sha256-YSLnnVXg8jVpjRHWV/OxlsUnPIMNoAsrATxaBI1eakI=";
                  };
                }
                {
                  name = "vae/ae.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors";
                    hash = "sha256-r8jignLNFds5GbrNtpGM6cHtIulssSxNXtD7qCNSnjg=";
                  };
                }
                {
                  name = "vae/wan_2.1_vae.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors";
                    hash = "sha256-L8OdMTWaSwpk9Vh22P9/qNeAlWriyxNGOwIj4VFIl2s=";
                  };
                }
                {
                  name = "vae/qwen_image_vae.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors";
                    hash = "sha256-pwWA8CE+Z5Z+6clfBbtADo+wgwfgF6kkvzRBIj4CPR8=";
                  };
                }
                {
                  name = "checkpoints/v1-5-pruned-emaonly-fp16.safetensors";
                  path = pkgs.fetchurl {
                    url = "https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors";
                    hash = "sha256-6UdqE3KM112Cefbsi611OmahlXyjdaFGTcY7N9tuORY=";
                  };
                }
              ];
              text_encoders = "text_encoders";
              loras = "loras";
              diffusion_models = "diffusion_models";
              vae = "vae";
              checkpoints = "checkpoints";
            };
          }
        ))
      ];
    };
  };

}
