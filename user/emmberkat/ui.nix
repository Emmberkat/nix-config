{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.emmberkat.ui.enable = lib.mkEnableOption "graphical applications";

  config = lib.mkIf config.emmberkat.ui.enable {
    programs = {
      obsidian.enable = true;
      hermes-agent = {
        enable = true;
        desktop.enable = true;
      };
    };

    home.packages = with pkgs; [
      discord
      picard
      prismlauncher
    ];
  };
}
