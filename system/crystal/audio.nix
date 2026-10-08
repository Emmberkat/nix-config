_: {
  services.pipewire.wireplumber.extraConfig = {
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
}
