{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    swaybg
    nautilus
    vlc
    file-roller
    nextcloud-client
    zulip
    # Open-source RDP client (xfreerdp) for Citrix VDI / RDP; runs under XWayland.
    freerdp
    makemkv
  ];

  # Shows polkit password prompts (e.g. fprintd-enroll); sway has no agent.
  services.polkit-gnome.enable = true;

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
  };
  qt = {
    enable = true;
    style.name = "adwaita-dark";
  };

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    config = {
      assigns."4" = [ { class = "^steam$"; } ];
      startup = [
        {
          command = "swaybg -i .background-image";
        }
      ];
      modifier = "Mod4";
      menu = "${pkgs.wofi}/bin/wofi --show drun";
      terminal = "${pkgs.foot}/bin/foot";
      keybindings = lib.mkOptionDefault {
        "Mod4+l" = "exec swaylock";
        "--locked XF86AudioRaiseVolume" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
        "--locked XF86AudioLowerVolume" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "--locked XF86AudioMute" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "--locked XF86AudioMicMute" =
          "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        # brightnessctl sets the backlight through logind, so no video group or udev rule is needed.
        "--locked XF86MonBrightnessUp" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
        "--locked XF86MonBrightnessDown" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
      };
      bars = [ ];
    };
  };
  programs = {
    foot.enable = true;
    swaylock.enable = true;
    waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          modules-left = [ "sway/workspaces" ];
          modules-center = [ "sway/window" ];
          # battery hides itself on machines without one.
          modules-right = [
            "wireplumber"
            "cpu"
            "memory"
            "temperature"
            "battery"
            "clock"
            "tray"
          ];
        };
      };
    };
  };

  # The desktop's Kanban plugin ships off (`defaultEnabled: false`), and the
  # on/off switch lives in the app's localStorage, which Nix can't seed. Flip
  # the plugin's own default in the renderer source instead; a switch turned
  # off by hand in Settings > Plugins still wins.
  programs.hermes-agent.desktop.package =
    config.programs.hermes-agent.package.hermesDesktop.override
      (prev: {
        hermesNpmLib = prev.hermesNpmLib // {
          buildPnpmPackage =
            attrs:
            prev.hermesNpmLib.buildPnpmPackage (
              attrs
              // {
                postPatch = (attrs.postPatch or "") + ''
                  substituteInPlace apps/desktop/src/plugins/kanban/plugin.tsx \
                    --replace-fail "defaultEnabled: false," "defaultEnabled: true,"
                '';
              }
            );
        };
      });
}
