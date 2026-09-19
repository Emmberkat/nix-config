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

  };

}
