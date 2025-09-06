{ ... }:
{
  programs = {
    git = {
      enable = true;
      lfs.enable = true;
      userName = "Emma Benkart";
      userEmail = "emmabenkart@gmail.com";
      extraConfig = {
        init.defaultBranch = "main";
      };
    };
    gh.enable = true;
  };
}
