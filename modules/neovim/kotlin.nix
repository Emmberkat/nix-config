{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.kotlin;
in
{
  options.emmberkat.neovim.kotlin.enable = mkEnableOption "kotlin" // {
    default = true;
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      extraLuaConfig = ''
        vim.lsp.config('kotlin_language_server', {
          cmd = { '${pkgs.kotlin-language-server}/bin/kotlin-language-server' }
        })
        vim.lsp.enable('kotlin_language_server')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.kotlin
      ];
    };
  };
}
