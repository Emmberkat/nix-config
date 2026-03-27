{
  pkgs,
  config,
  ...
}:
{

  home.packages = with pkgs; [
    qwen-code
  ];

}
