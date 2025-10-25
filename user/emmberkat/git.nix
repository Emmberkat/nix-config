{ ... }:
{
  programs = {
    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user = {
          name = "Emma Benkart";
          email = "emmabenkart@gmail.com";
        };
        init.defaultBranch = "main";
      };
    };
    gh.enable = true;
  };
}
