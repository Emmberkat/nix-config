{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.ocaml;
in
{
  options.emmberkat.neovim.ocaml.enable = mkEnableOption "ocaml";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      ocamlPackages.ocaml-lsp
      ocamlPackages.ocamlformat
    ];
    programs.neovim = {
      initLua = ''
        vim.lsp.enable('ocamllsp')
      '';
      plugins = [
        pkgs.vimPlugins.nvim-treesitter-parsers.ocaml
      ];
    };
  };
}
