{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.go;
in
{
  options.emmberkat.neovim.go.enable = mkEnableOption "go" // {
    default = true;
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      go
      gopls
    ];
    programs.neovim = {
      initLua = ''
        vim.lsp.enable('gopls')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.go
      ];
    };
  };
}
