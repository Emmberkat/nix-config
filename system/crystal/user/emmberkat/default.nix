{
  config,
  pkgs,
  ...
}:
{

  imports = [
    ./backups.nix
    ./desktop.nix
  ];

  programs.openclaw = {
    enable = true;
    # This machine is a node — it connects to catalyst as a remote Gateway.
    # No own gateway, no channels, no local model provider.
    config = {
      gateway = {
        remote = {
          url = "http://10.1.0.1:18789";
          token = {
            source = "env";
            provider = "default";
            id = "OPENCLAW_GATEWAY_TOKEN";
          };
        };
      };
    };
  };

}
