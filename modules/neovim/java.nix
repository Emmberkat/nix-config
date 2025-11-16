{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.java;
in
{
  options.emmberkat.neovim.java.enable = mkEnableOption "java" // {
    default = true;
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      extraLuaConfig = ''
        vim.lsp.config('jdtls', {
          cmd = { '${pkgs.jdt-language-server}/bin/jdt-language-server' }
        })
        vim.lsp.enable('jdtls')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.java
      ];
    };
  };
}
