_:
let
  openwebuiPort = 8040;
in
{
  services = {
    nginx.virtualHosts."llm.emmberkat.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString openwebuiPort}";
        proxyWebsockets = true;
      };
    };

    open-webui = {
      enable = true;
      port = openwebuiPort;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
      };
    };

  };

}
