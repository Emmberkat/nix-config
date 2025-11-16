{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.rust;
in
{
  options.emmberkat.neovim.rust.enable = mkEnableOption "rust" // {
    default = true;
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      extraLuaConfig = ''
        vim.lsp.config('rust_analyzer', {
          cmd = { '${pkgs.rust-analyzer}/bin/rust-analyzer' }
        })
        vim.lsp.enable('rust_analyzer')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.rust
      ];
    };
  };
}
