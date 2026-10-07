{
  pkgs,
  ...
}:
{
  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      extraLadspaPackages = [ pkgs.rnnoise-plugin ];
      wireplumber.enable = true;
      # Noise-canceling capture source (rnnoise).
      extraConfig.pipewire = {
        "91-null-sinks" = {
          "context.modules" = [
            {
              "name" = "libpipewire-module-filter-chain";
              "args" = {
                "node.description" = "Noise Canceling Source";
                "media.name" = "Noise Canceling Source";
                "filter.graph" = {
                  "nodes" = [
                    {
                      "type" = "ladspa";
                      "name" = "rnnoise";
                      "plugin" = "librnnoise_ladspa";
                      "label" = "noise_suppressor_mono";
                      "control" = {
                        "VAD Threshold (%)" = 90.0;
                      };
                    }
                  ];
                };
                "capture.props" = {
                  "node.name" = "capture.rnnoise_source";
                  "node.passive" = true;
                  "audio.rate" = 48000;
                };
                "playback.props" = {
                  "node.name" = "rnnoise_source";
                  "media.class" = "Audio/Source";
                  "audio.rate" = 48000;
                };
              };
            }
          ];
        };
      };
    };
  };
}
