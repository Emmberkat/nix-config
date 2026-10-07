{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.html;
in
{
  options.emmberkat.neovim.html.enable = mkEnableOption "html" // {
    default = true;
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      vscode-langservers-extracted
    ];
    programs.neovim = {
      initLua = ''
        vim.lsp.enable('html')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.html
      ];
    };
  };
}
