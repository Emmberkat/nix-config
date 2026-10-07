{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.typescript;
in
{
  options.emmberkat.neovim.typescript.enable = mkEnableOption "typescript";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      typescript-language-server
    ];
    programs.neovim = {
      initLua = ''
        vim.lsp.enable('ts_ls')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.typescript
      ];
    };
  };
}
