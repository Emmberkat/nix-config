{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.nix;
in
{
  options.emmberkat.neovim.nix.enable = mkEnableOption "nix" // {
    default = true;
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nil
      nixpkgs-fmt
    ];
    programs.neovim = {
      initLua = ''
        vim.lsp.config('nil_ls', {
          settings = {
            ['nil'] = {
              formatting = {
                command = { "nixpkgs-fmt" },
              },
            },
          },
        })
        vim.lsp.enable('nil_ls')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.nix
      ];
    };
  };
}
