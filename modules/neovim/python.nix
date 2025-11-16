{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.python;
in
{
  options.emmberkat.neovim.python.enable = mkEnableOption "python" // {
    default = true;
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      extraLuaConfig = ''
        vim.lsp.config('pyright', {
          cmd = { '${pkgs.pyright}/bin/pyright-langserver', '--stdio' }
        })
        vim.lsp.enable('pyright')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.python
      ];
    };
  };
}
