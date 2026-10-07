{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.emmberkat.neovim.yaml;
in
{
  options.emmberkat.neovim.yaml.enable = mkEnableOption "yaml" // {
    default = true;
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      yaml-language-server
    ];
    programs.neovim = {
      initLua = ''
        vim.lsp.enable('yamlls')
      '';
    };
  };
}
