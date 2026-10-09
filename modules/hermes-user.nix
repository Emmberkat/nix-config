{
  # Shared "hermes" user for hosts that are not the hermes-agent host itself
  # (catalyst defines hermes as a system user via the hermes-agent module).
  # Grants journal read access and a restricted SSH key from catalyst, so the
  # agent can pull logs from these hosts.
  users.users.hermes = {
    isNormalUser = true;
    extraGroups = [ "systemd-journal" ];
    openssh.authorizedKeys.keys = [
      "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMXio8G3QOGD7JVNtXC2L8My3TF8wpq7KIwdIhBsUUr hermes@catalyst"
    ];
  };
}
