_:
{
  # Single-user personal instance; the module auto-generates its secrets
  # (secret-key-base, AR encryption, VAPID) into /var/lib/mastodon/secrets
  # on first activation, so no agenix files are needed.
  services.mastodon = {
    enable = true;
    localDomain = "mastodon.emmberkat.com";
    configureNginx = true;
    smtp.fromAddress = "noreply@mastodon.emmberkat.com";
    extraConfig.SINGLE_USER_MODE = "true";
    streamingProcesses = 15; # 16 cores minus one
  };
}
