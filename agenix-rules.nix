let
  keysDir = ./publickeys;
  keyFiles = builtins.readDir keysDir;
  keys = builtins.mapAttrs (name: _value: builtins.readFile (keysDir + "/${name}")) keyFiles;
in
{
  "system/crystal/user/emmberkat/secrets/syncthing/key.age" = {
    publicKeys = [
      keys.admin
      keys.emmberkat
      keys.crystal
    ];
    armor = true;
  };
  "system/crystal/user/emmberkat/secrets/syncthing/cert.age" = {
    publicKeys = [
      keys.admin
      keys.emmberkat
      keys.crystal
    ];
    armor = true;
  };
  "system/catalyst/secrets/ddclient/password.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/frigate/environment.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/garage/rpc_secret.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/nextcloud/adminpass.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/nextcloud/s3secret.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/searx/environment.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/hermes/claude-oauth-token.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/hermes/messaging-env.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/hermes/mcp.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/hermes/nextcloud-env.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/hermes/api-server-key.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/pocketid/key.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/open-webui/api-server-key.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/comfyui/oauth2-proxy-cookie-secret.age" = {
    publicKeys = [
      keys.admin
      keys.catalyst
    ];
    armor = true;
  };
}
