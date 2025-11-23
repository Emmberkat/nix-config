{
  pkgs,
  config,
  ...
}:
{

  home.packages = with pkgs; [
    goose-cli
  ];

}
