let
  keysDir = ./publickeys;
  keyFiles = builtins.readDir keysDir;
  keys = builtins.mapAttrs (name: value: builtins.readFile (keysDir + "/${name}")) keyFiles;
in
{
  "system/crystal/secrets/syncthing/key.age" = {
    publicKeys = [
      keys.emmberkat
      keys.crystal
    ];
    armor = true;
  };
  "system/crystal/secrets/syncthing/cert.age" = {
    publicKeys = [
      keys.emmberkat
      keys.crystal
    ];
    armor = true;
  };
  "user/emmberkat/secrets/restic/environment.age" = {
    publicKeys = [
      keys.emmberkat
      keys.crystal
    ];
    armor = true;
  };
  "user/emmberkat/secrets/restic/password.age" = {
    publicKeys = [
      keys.emmberkat
      keys.crystal
    ];
    armor = true;
  };
  "system/catalyst/secrets/ddclient/password.age" = {
    publicKeys = [
      keys.catalyst
    ];
    armor = true;
  };
  "system/catalyst/secrets/minio/credentials.age" = {
    publicKeys = [
      keys.catalyst
    ];
    armor = true;
  };
}
