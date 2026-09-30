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
    };

    home.packages = with pkgs; [
      discord
      picard
      prismlauncher
    ];
  };
}
