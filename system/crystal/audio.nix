{
  pkgs,
  ...
}:
{

  services = {
    pulseaudio.enable = false;

    pipewire = {

      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber = {
        enable = true;

        extraConfig = {
          "51-disable-devices" = {
            "monitor.alsa.rules" = [
              {
                matches = [
                  { "device.name" = "alsa_card.pci-0000_01_00.1"; }
                  { "device.name" = "alsa_card.pci-0000_00_1f.3"; }
                  { "device.name" = "alsa_card.usb-046d_Logitech_BRIO_5968AB13-03"; }
                ];
                actions = {
                  update-props = {
                    "device.disabled" = true;
                  };
                };
              }
            ];
          };
          "51-disable-nodes" = {
            "monitor.alsa.rules" = [
              {
                matches = [
                  { "node.name" = "alsa_output.usb-R__DE_R__DE_PodMic_USB_F95EE208-00.analog-stereo"; }
                ];
                actions = {
                  update-props = {
                    "node.disabled" = true;
                  };
                };
              }
            ];
          };
        };
      };

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
                      "plugin" = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
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
