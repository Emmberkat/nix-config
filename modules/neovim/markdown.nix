{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.markdown;
in
{
  options.emmberkat.neovim.markdown.enable = mkEnableOption "markdown" // {
    default = true;
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      rumdl
    ];
    programs.neovim = {
      initLua = ''
        vim.lsp.enable('rumdl')
      '';
    };
  };
}
